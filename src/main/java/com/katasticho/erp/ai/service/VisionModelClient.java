package com.katasticho.erp.ai.service;

public interface VisionModelClient {
    String sendMessage(String systemPrompt, String userMessage);
    String sendMessageWithImage(String systemPrompt, String textMessage,
                                String base64Image, String mediaType);
}
