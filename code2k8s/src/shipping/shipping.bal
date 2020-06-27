import ballerina/http;
import ballerina/system;
import ballerina/log;
import lakwarus/commons as x;
import ballerina/kubernetes;

http:Client ordermgtClient = new("http://ordermgt-svc:8081/OrderMgt");

@kubernetes:Service {
    name: "shipping-svc"
}
@kubernetes:Deployment {
    name: "shipping",
    livenessProbe: true,
    readinessProbe: true
}
service Shipping on new http:Listener(8083) {

    @http:ResourceConfig {
        path: "/delivery",
        body: "delivery",
        methods: ["POST"]
    }
    resource function processPayment(http:Caller caller, http:Request request, 
                                     x:Delivery delivery) returns @tainted error? {
        http:Response resp = check ordermgtClient->get("/order/" + <@untainted> delivery.orderId);
        x:Order order = check x:Order.constructFrom(check resp.getJsonPayload());
        string trackingNumber = system:uuid();
        check caller->respond(trackingNumber);
        log:printInfo("Shipping - OrderId: " + delivery.orderId + " TrackingNumber: " + trackingNumber);
    }

}