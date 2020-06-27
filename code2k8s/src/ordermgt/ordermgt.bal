import ballerina/http;
import ballerina/system;
import ballerina/log;
import lakwarus/commons as x;
import ballerina/kubernetes;

map<x:Order> orderMap = {};

@kubernetes:Service {
    name: "ordermgt-svc"
}
@kubernetes:Deployment {
    name: "ordermgt",
    livenessProbe: true,
    readinessProbe: true
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