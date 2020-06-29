import ballerina/http;
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
    conf: "src/inventory/ballerina.conf"
}
@kubernetes:Service {
    name: "inventory-svc"
}
@kubernetes:Deployment {
    name: "inventory",
    livenessProbe: true,
    readinessProbe: true,
    push: true,
    image: "index.docker.io/$env{DOCKER_USERNAME}/ecommerce-inventory:1.0",
    username: "$env{DOCKER_USERNAME}",
    password: "$env{DOCKER_PASSWORD}",
    prometheus: true
}
service Inventory on new http:Listener(8084) {

    @http:ResourceConfig {
        path: "/search/{query}",
        methods: ["GET"]
    }
    resource function search(http:Caller caller, http:Request request, 
                             string query) returns @tainted error? {
        var rs = check dbClient->select("SELECT id, description FROM ECOM_INVENTORY WHERE description LIKE '%" + 
                                        <@untainted> query + "%'", ());
        check caller->respond(jsonutils:fromTable(rs));
    }

}