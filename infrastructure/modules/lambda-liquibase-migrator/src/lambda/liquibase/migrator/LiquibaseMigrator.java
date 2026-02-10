package lambda.liquibase.migrator;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.amazonaws.services.secretsmanager.AWSSecretsManager;
import com.amazonaws.services.secretsmanager.AWSSecretsManagerClientBuilder;
import com.amazonaws.services.secretsmanager.model.GetSecretValueRequest;
import com.amazonaws.services.secretsmanager.model.GetSecretValueResult;
import liquibase.Liquibase;
import liquibase.database.Database;
import liquibase.database.DatabaseFactory;
import liquibase.resource.ClassLoaderResourceAccessor;
import liquibase.exception.LiquibaseException;
import liquibase.database.jvm.JdbcConnection;

import java.sql.Connection;
import java.sql.DriverManager;
import java.util.Map;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

public class LiquibaseMigrator implements RequestHandler<Map<String, String>, String> {
    private String getDBPassword(String secretArn) throws Exception {
        AWSSecretsManager client = AWSSecretsManagerClientBuilder.defaultClient();
        GetSecretValueRequest getSecretValueRequest = new GetSecretValueRequest().withSecretId(secretArn);
        GetSecretValueResult getSecretValueResult = client.getSecretValue(getSecretValueRequest);
        String secretString = getSecretValueResult.getSecretString();
        ObjectMapper mapper = new ObjectMapper();
        JsonNode secretJson = mapper.readTree(secretString);
        if (!secretJson.has("password")) {
            throw new Exception("password field not found in secret");
        }
        return secretJson.get("password").asText();
    }

    private String buildJdbcUrl() throws Exception {
        String user = System.getenv("DB_USERNAME");
        String host = System.getenv("DB_ADDRESS");
        String port = System.getenv("DB_PORT");
        String dbname = System.getenv("DB_NAME");
        String secretArn = System.getenv("DB_SECRET_ARN");
        if (user == null || host == null || port == null || dbname == null || secretArn == null) {
            throw new Exception("Missing one or more required environment variables");
        }
        String password = getDBPassword(secretArn);
        return String.format("jdbc:postgresql://%s:%s/%s?user=%s&password=%s", host, port, dbname, user, password);
    }

    @Override
    public String handleRequest(Map<String, String> event, Context context) {
        try {
            String jdbcUrl = buildJdbcUrl();
            try (Connection conn = DriverManager.getConnection(jdbcUrl)) {
                Database database = DatabaseFactory.getInstance().findCorrectDatabaseImplementation(new JdbcConnection(conn));
                Liquibase liquibase = new Liquibase("changelog/db.changelog-master.xml", new ClassLoaderResourceAccessor(), database);
                liquibase.update((String) null);
                return "Migration successful";
            }
        } catch (LiquibaseException | java.sql.SQLException | Exception e) {
            return "Migration failed: " + e.getMessage();
        }
    }
}
