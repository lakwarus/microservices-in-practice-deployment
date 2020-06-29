import ballerina/http;
import ballerina/system;
import ballerina/log;
import lakwarus/commons as x;
import ballerina/kubernetes;

http:Client orderMgtClient = new("http://ordermgt-svc:8081/OrderMgt");

@kubernetes:HPA {
    minReplicas: 1,
    maxReplicas: 2,
    cpuPercentage: 75,
    name: "billing-hpa"
}
@kubernetes:Service {
    name: "billing-svc"
}
@kubernetes:Deployment {
    name: "billing",
    livenessProbe: true,
    readinessProbe: true,
    push: true,
    image: "index.docker.io/$env{DOCKER_USERNAME}/ecommerce-billing:1.0",
    username: "$env{DOCKER_USERNAME}",
    password: "$env{DOCKER_PASSWORD}",
    prometheus: true
}
service Billing on new http:Listener(8082) {

    @http:ResourceConfig {
        path: "/payment",
        body: "payment",
        methods: ["POST"]
    }
    resource function processPayment(http:Caller caller, http:Request request, 
                                     x:Payment payment) returns @tainted error? {
        http:Response resp = check orderMgtClient->get("/order/" + <@untainted> payment.orderId);
        x:Order order = check x:Order.constructFrom(check resp.getJsonPayload());
        string receiptNumber = system:uuid();
        check caller->respond(receiptNumber);
        log:printInfo("Billing - OrderId: " + payment.orderId + " ReceiptNumber: " + receiptNumber);
    }

}