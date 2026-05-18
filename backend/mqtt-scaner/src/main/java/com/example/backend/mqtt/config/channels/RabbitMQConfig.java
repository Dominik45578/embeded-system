package com.example.backend.mqtt.config.channels;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.amqp.core.*;
import org.springframework.amqp.support.converter.Jackson2JsonMessageConverter;
import org.springframework.amqp.support.converter.MessageConverter;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class RabbitMQConfig {

    public static final String QUEUE_LOCK_STATE_CHANGE = "lock-state-change";
    public static final String EXCHANGE_LOCK = "lock-exchange";
    public static final String ROUTING_KEY_LOCK_STATE = "lock.state.change";

    @Bean
    public Queue lockStateChangeQueue() {
        return new Queue(QUEUE_LOCK_STATE_CHANGE, true);
    }

    @Bean
    public TopicExchange lockExchange() {
        return new TopicExchange(EXCHANGE_LOCK);
    }

    @Bean
    public Binding lockStateChangeBinding(Queue lockStateChangeQueue, TopicExchange lockExchange) {
        return BindingBuilder.bind(lockStateChangeQueue).to(lockExchange).with(ROUTING_KEY_LOCK_STATE);
    }

    @Bean
    public MessageConverter jsonMessageConverter(ObjectMapper objectMapper) {
        return new Jackson2JsonMessageConverter(objectMapper);
    }
}