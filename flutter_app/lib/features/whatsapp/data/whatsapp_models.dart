class WhatsAppMessageModel {
  final String id;
  final String recipient;
  final String docType;
  final String? docId;
  final String? templateName;
  final String status;
  final String? provider;
  final String? providerMessageId;
  final String? errorMessage;
  final String? sentAt;
  final String direction;
  final String? body;

  const WhatsAppMessageModel({
    required this.id,
    required this.recipient,
    required this.docType,
    this.docId,
    this.templateName,
    required this.status,
    this.provider,
    this.providerMessageId,
    this.errorMessage,
    this.sentAt,
    this.direction = 'OUTBOUND',
    this.body,
  });

  factory WhatsAppMessageModel.fromJson(Map<String, dynamic> json) {
    return WhatsAppMessageModel(
      id: json['id']?.toString() ?? '',
      recipient: json['recipient']?.toString() ?? '',
      docType: json['docType']?.toString() ?? 'DOCUMENT',
      docId: json['docId']?.toString(),
      templateName: json['templateName']?.toString(),
      status: json['status']?.toString() ?? 'SENT',
      provider: json['provider']?.toString(),
      providerMessageId: json['providerMessageId']?.toString(),
      errorMessage: json['errorMessage']?.toString(),
      sentAt: json['sentAt']?.toString() ?? json['createdAt']?.toString(),
      direction: json['direction']?.toString() ?? 'OUTBOUND',
      body: json['body']?.toString(),
    );
  }
}

class BotReplyModel {
  final String replyText;
  final String intent;
  final String actionTaken;
  final String status;
  final String? relatedDocId;
  final String? docType;

  const BotReplyModel({
    required this.replyText,
    required this.intent,
    required this.actionTaken,
    required this.status,
    this.relatedDocId,
    this.docType,
  });

  factory BotReplyModel.fromJson(Map<String, dynamic> json) {
    return BotReplyModel(
      replyText: json['replyText']?.toString() ?? '',
      intent: json['intent']?.toString() ?? 'GENERAL',
      actionTaken: json['actionTaken']?.toString() ?? 'NONE',
      status: json['status']?.toString() ?? 'COMPLETED',
      relatedDocId: json['relatedDocId']?.toString(),
      docType: json['docType']?.toString(),
    );
  }
}

class WhatsAppSettingsModel {
  final bool enabled;
  final String provider;
  final String? phoneNumberId;
  final String? customUrl;
  final String lang;
  final bool autoSendReceipt;
  final bool apiKeySet;
  final String? webhookToken;
  final String? webhookUrl;
  final String? verifyToken;
  final String? templateInvoice;
  final String? templateReceipt;
  final String? templateReminder;

  const WhatsAppSettingsModel({
    this.enabled = false,
    this.provider = 'META',
    this.phoneNumberId,
    this.customUrl,
    this.lang = 'en',
    this.autoSendReceipt = false,
    this.apiKeySet = false,
    this.webhookToken,
    this.webhookUrl,
    this.verifyToken,
    this.templateInvoice,
    this.templateReceipt,
    this.templateReminder,
  });

  factory WhatsAppSettingsModel.fromJson(Map<String, dynamic> json) {
    return WhatsAppSettingsModel(
      enabled: json['enabled'] == true,
      provider: json['provider']?.toString() ?? 'META',
      phoneNumberId: json['phoneNumberId']?.toString(),
      customUrl: json['customUrl']?.toString(),
      lang: json['lang']?.toString() ?? 'en',
      autoSendReceipt: json['autoSendReceipt'] == true,
      apiKeySet: json['apiKeySet'] == true,
      webhookToken: json['webhookToken']?.toString(),
      webhookUrl: json['webhookUrl']?.toString(),
      verifyToken: json['verifyToken']?.toString(),
      templateInvoice: json['templateInvoice']?.toString(),
      templateReceipt: json['templateReceipt']?.toString(),
      templateReminder: json['templateReminder']?.toString(),
    );
  }
}

class BotSimulationRequestPayload {
  final String? contactId;
  final String message;
  final String? fromPhone;

  const BotSimulationRequestPayload({
    this.contactId,
    required this.message,
    this.fromPhone,
  });

  Map<String, dynamic> toJson() => {
        if (contactId != null) 'contactId': contactId,
        'message': message,
        if (fromPhone != null) 'fromPhone': fromPhone,
      };
}
