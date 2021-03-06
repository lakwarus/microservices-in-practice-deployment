import ballerina/http;
import ballerina/system;
import ballerina/log;
import lakwarus/commons as x;
import ballerina/kubernetes;

http:Client ordermgtClient = new("http://ordermgt-svc:8081/OrderMgt");

@kubernetes:HPA {
    minReplicas: 1,
    maxReplicas: 2,
    cpuPercentage: 75,
    name: "shipping-hpa"
}
@kubernetes:Service {
    name: "shipping-svc"
}
@kubernetes:Deployment {
    name: "shipping",
    livenessProbe: true,
    readinessProbe: true,
    push: true,
    image: "index.docker.io/$env{DOCKER_USERNAME}/ecommerce-shipping:1.0",
    username: "$env{DOCKER_USERNAME}",
    password: "$env{DOCKER_PASSWORD}",
    prometheus: true
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