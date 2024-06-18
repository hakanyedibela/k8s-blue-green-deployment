package hkn7b.dev;

import io.quarkus.test.junit.QuarkusTest;
import org.junit.jupiter.api.Test;

import static io.restassured.RestAssured.given;
import static org.hamcrest.CoreMatchers.is;

@QuarkusTest
class ExampleResourceTest {
    @Test
    void testHelloEndpoint() {
        given()
                .when().get("/green")
                .then()
                .statusCode(200)
                .body(is("Green Application is up and running!"));
    }

}