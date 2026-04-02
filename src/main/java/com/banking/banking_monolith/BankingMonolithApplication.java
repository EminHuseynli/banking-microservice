package com.banking.banking_monolith;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableAsync;

import java.awt.*;
import java.net.URI;

@SpringBootApplication
@EnableAsync
public class BankingMonolithApplication {

	public static void main(String[] args) {
		SpringApplication.run(BankingMonolithApplication.class, args);
		openSwaggerUi();
	}

	private static void openSwaggerUi() {
		try {
			Desktop.getDesktop().browse(new URI("http://localhost:8080/swagger-ui/index.html"));
		} catch (Exception ignored) {
		}
	}


//


}
