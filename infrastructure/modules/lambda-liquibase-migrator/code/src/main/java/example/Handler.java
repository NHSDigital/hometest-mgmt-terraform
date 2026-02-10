package example;

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

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class Handler implements RequestHandler<Map<String, String>, String> {
    private static final Logger logger = LoggerFactory.getLogger(Handler.class);

    private String getDBPassword(String secretArn) throws Exception {
        logger.info("Fetching DB password from Secrets Manager for ARN: {}", secretArn);
        AWSSecretsManager client = AWSSecretsManagerClientBuilder.defaultClient();
        GetSecretValueRequest getSecretValueRequest = new GetSecretValueRequest().withSecretId(secretArn);
        GetSecretValueResult getSecretValueResult = client.getSecretValue(getSecretValueRequest);
        String secretString = getSecretValueResult.getSecretString();
        logger.debug("Secret string retrieved: {}", secretString != null ? "[REDACTED]" : null);
        ObjectMapper mapper = new ObjectMapper();
        JsonNode secretJson = mapper.readTree(secretString);
        if (!secretJson.has("password")) {
            logger.error("Password field not found in secret JSON");
            throw new IllegalArgumentException("password field not found in secret");
        }
        logger.info("Password field found in secret JSON");
        return secretJson.get("password").asText();
    }

    private String buildJdbcUrl() throws Exception {
        logger.info("Building JDBC URL from environment variables");
        String user = System.getenv("DB_USERNAME");
        String host = System.getenv("DB_ADDRESS");
        String port = System.getenv("DB_PORT");
        String dbname = System.getenv("DB_NAME");
        String secretArn = System.getenv("DB_SECRET_ARN");
        if (user == null || host == null || port == null || dbname == null || secretArn == null) {
            logger.error("Missing one or more required environment variables");
            throw new IllegalArgumentException("Missing one or more required environment variables");
        }
        String password = getDBPassword(secretArn);
        String jdbcUrl = String.format("jdbc:postgresql://%s:%s/%s?user=%s&password=%s", host, port, dbname, user, password);
        logger.info("JDBC URL built: jdbc:postgresql://{}:{}...", host, port);
        return jdbcUrl;
    }

    @Override
    public String handleRequest(Map<String, String> event, Context context) {
        logger.info("Starting Liquibase migration Lambda handler");
        try {
            String jdbcUrl = buildJdbcUrl();
            logger.info("Connecting to DB with JDBC URL");
            try (Connection conn = DriverManager.getConnection(jdbcUrl)) {
                Database database = DatabaseFactory.getInstance().findCorrectDatabaseImplementation(new JdbcConnection(conn));
                Liquibase liquibase = new Liquibase("changelog/db.changelog-master.xml", new ClassLoaderResourceAccessor(), database);
                logger.info("Running Liquibase update");
                liquibase.update((String) null);
                logger.info("Migration successful");
                return "Migration successful";
            }
        } catch (Exception e) {
            logger.error("Migration failed", e);
            return "Migration failed: " + e.getMessage();
        }
    }
}
