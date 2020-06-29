import ballerina/http;
import ballerina/encoding;
import lakwarus/commons as x;
import ballerina/kubernetes;

http:Client cartClient = new("http://cart-svc:8080/ShoppingCart");
http:Client orderMgtClient = new("http://ordermgt-svc:8081/OrderMgt");
http:Client billingClient = new("http://billing-svc:8082/Billing");
http:Client shippingClient = new("http://shipping-svc:8083/Shipping");
http:Client invClient = new("http://inventory-svc:8084/Inventory");

@kubernetes:Service {
    name: "admin-svc",
    serviceType: "NodePort",
    nodePort: 30300
}
@kubernetes:Deployment {
    name: "admin",
    livenessProbe: true,
    readinessProbe: true,
    push: true,
    image: "index.docker.io/$env{DOCKER_USERNAME}/ecommerce-admin:1.0",
    username: "$env{DOCKER_USERNAME}",
    password: "$env{DOCKER_PASSWORD}",
    prometheus: true
}
service Admin on new http:Listener(8085) {

    @http:ResourceConfig {
        path: "/invsearch/{query}",
        methods: ["GET"]
    }
    resource function search(http:Caller caller, http:Request request, 
                             string query) returns @tainted error? {
        http:Response resp = check invClient->get("/search/" + <@untainted> check encoding:encodeUriComponent(query, "UTF-8"));
        check caller->respond(resp);
    }

    @http:ResourceConfig {
        path: "/cartitems/{accountId}",
        body: "item",
        methods: ["POST"]
    }
    resource function addItem(http:Caller caller, http:Request request, 
                              int accountId, x:Item item) returns error? {
        http:Response resp = check cartClient->post("/items/" + <@untainted> accountId.toString(), 
                                                    <@untainted> check json.constructFrom(item));
        check caller->respond(resp);
    }

    @http:ResourceConfig {
        path: "/checkout/{accountId}"
    }
    resource function checkout(http:Caller caller, http:Request request, int accountId) returns @tainted error? {
        http:Response resp = check cartClient->get("/items/" + <@untainted> accountId.toString());
        x:Item[] items = check x:Item[].constructFrom(check resp.getJsonPayload());
        if items.length() == 0 {
            http:Response respx = new;
            respx.statusCode = 400;
            respx.setTextPayload("Empty cart");
            check caller->respond(respx);
            return;
        }
        x:Order order = { accountId, items };
        resp = check orderMgtClient->post("/order", <@untainted> check json.constructFrom(order));
        string orderId = check resp.getTextPayload();
        x:Payment payment = { orderId };
        resp = check billingClient->post("/payment", <@untainted> check json.constructFrom(payment));
        string receiptNumber = check resp.getTextPayload();
        x:Delivery delivery = { orderId };
        resp = check shippingClient->post("/delivery", <@untainted> check json.constructFrom(delivery));
        string trackingNumber = check resp.getTextPayload();
        _ = check cartClient->delete("/items/" + <@untainted> accountId.toString());
        check caller->ok(<@untainted> { accountId: accountId, orderId: orderId, receiptNumber: receiptNumber, 
                                        trackingNumber: trackingNumber });
    }

}