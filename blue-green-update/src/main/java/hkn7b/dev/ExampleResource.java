package hkn7b.dev;

import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;

@Path("/green")
public class ExampleResource {

    @GET
    @Produces(MediaType.APPLICATION_JSON)
    public String hello() {
        return "Green Application is up and running!";
    }
}
