import ballerina/http;
import ballerina/system;
import ballerina/log;
import lakwarus/commons as x;
import ballerina/kubernetes;

map<x:Order> orderMap = {};

@kubernetes:HPA {
    minReplicas: 1,
    maxReplicas: 4,
    cpuPercentage: 75,
    name: "ordermgt-hpa"
}
@kubernetes:Service {
    name: "ordermgt-svc"
}
@kubernetes:Deployment {
    name: "ordermgt",
    image: "index.docker.io/$env{DOCKER_USERNAME}/ecommerce-ordermgt:1.0",
    username: "$env{DOCKER_USERNAME}",
    password: "$env{DOCKER_PASSWORD}",
    push: true,
    livenessProbe: true,
    readinessProbe: true,
    prometheus: true
}
service OrderMgt on new http:Listener(8081) {

    @http:ResourceConfig {
        path: "/order/",
        body: "order",
        methods: ["POST"]
    }
    resource function createOrder(http:Caller caller, http:Request request, 
                                  x:Order order) returns @tainted error? {
        string orderId = system:uuid();
        orderMap[orderId] = <@untainted> order;
        check caller->ok(orderId);
        log:printInfo("OrderMgt - OrderId: " + orderId + " AccountId: " + order.accountId.toString());
    }

    @http:ResourceConfig {
        path: "/order/{orderId}",
        methods: ["GET"]
    }
    resource function getOrder(http:Caller caller, http:Request request, 
                               string orderId) returns @tainted error? {
        check caller->respond(check json.constructFrom(orderMap[orderId]));
    }

}