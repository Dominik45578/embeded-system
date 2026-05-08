package com.example.backend.config;

import com.influxdb.v3.client.InfluxDBClient;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class InfluxConfig {

    @Bean
    public InfluxDBClient influxDBClient(@Value("${BACKEND.INFLUX.HOST}") String host, @Value("${BACKEND.INFLUX.TOKEN}") String token, @Value("${BACKEND.INFLUX.DATABASE}") String db) {
        return InfluxDBClient.getInstance(host, token.toCharArray(), db);
    }

}
