import ballerina/http;
import lakwarus/commons as x;
import ballerinax/java.jdbc;
import ballerina/jsonutils;
import ballerina/config;
import ballerina/kubernetes;

jdbc:Client dbClient = new ({
    url: "jdbc:mysql://mysql-svc:3306/ECOM_DB?serverTimezone=UTC",
    username: config:getAsString("db.username"),
    password: config:getAsString("db.password"),
    poolOptions: { maximumPoolSize: 5 },
    dbOptions: { useSSL: false }
});

@kubernetes:ConfigMap {
    conf: "src/cart/ballerina.conf"
}
@kubernetes:Service {
    name: "cart-svc"
}
@kubernetes:Deployment {
    name: "cart",
    livenessProbe: true,
    readinessProbe: true,
    push: true,
    image: "index.docker.io/$env{DOCKER_USERNAME}/ecommerce-cart:1.0",
    username: "$env{DOCKER_USERNAME}",
    password: "$env{DOCKER_PASSWORD}"
}
service ShoppingCart on new http:Listener(8080) {

    @http:ResourceConfig {
        path: "/items/{accountId}",
        body: "item",
        methods: ["POST"]
    }
    resource function addItem(http:Caller caller, http:Request request, 
                              int accountId, x:Item item) returns error? {
        _ = check dbClient->update("INSERT INTO ECOM_ITEM (inventory_id, account_id, quantity) VALUES (?,?,?)", 
                                   item.invId, accountId, item.quantity);
        check caller->ok();
    }

    @http:ResourceConfig {
        path: "/items/{accountId}",
        methods: ["GET"]
    }
    resource function getItems(http:Caller caller, http:Request request, 
                               string accountId) returns @tainted error? {
        var rs = check dbClient->select("SELECT inventory_id as invId, quantity FROM ECOM_ITEM WHERE account_id = ?", 
                                        x:Item, accountId);
        check caller->ok(jsonutils:fromTable(rs));
    }

    @http:ResourceConfig {
        path: "/items/{accountId}",
        methods: ["DELETE"]
    }
    resource function clearItems(http:Caller caller, http:Request request, 
                                 string accountId) returns error? {
        _ = check dbClient->update("DELETE FROM ECOM_ITEM WHERE account_id = ?", accountId);
        check caller->ok();
    }

}