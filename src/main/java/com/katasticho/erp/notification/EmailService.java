package com.katasticho.erp.notification;

import jakarta.mail.MessagingException;
import jakarta.mail.internet.MimeMessage;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.MimeMessageHelper;
import org.springframework.stereotype.Service;

@Service
@Slf4j
public class EmailService {

    private final JavaMailSender mailSender;
    private final String fromEmail;
    private final String fromName;
    private final String baseUrl;
    private final String platformAdminUrl;

    public EmailService(
            JavaMailSender mailSender,
            @Value("${app.mail.from}") String fromEmail,
            @Value("${app.mail.from-name}") String fromName,
            @Value("${app.base-url}") String baseUrl,
            @Value("${app.platform-admin-url}") String platformAdminUrl) {
        this.mailSender = mailSender;
        this.fromEmail = fromEmail;
        this.fromName = fromName;
        this.baseUrl = baseUrl;
        this.platformAdminUrl = platformAdminUrl;
    }

    public void sendEmailVerification(String toEmail, String userName, String token) {
        String link = baseUrl + "/verify-email?token=" + token;
        String html = """
                <h2>Welcome to Katixo, %s!</h2>
                <p>Please verify your email address to continue.</p>
                <p><a href="%s" style="background:#4F46E5;color:white;padding:12px 24px;text-decoration:none;border-radius:6px;display:inline-block;">Verify Email</a></p>
                <p>This link expires in 24 hours.</p>
                """.formatted(userName, link);
        send(toEmail, "Verify your Katixo email", html);
    }

    public void sendPasswordReset(String toEmail, String userName, String token) {
        String link = baseUrl + "/reset-password?token=" + token;
        String html = """
                <h2>Password Reset Request</h2>
                <p>Hi %s, we received a request to reset your Katixo password.</p>
                <p><a href="%s" style="background:#4F46E5;color:white;padding:12px 24px;text-decoration:none;border-radius:6px;display:inline-block;">Reset Password</a></p>
                <p>This link expires in 30 minutes. If you did not request this, ignore this email.</p>
                """.formatted(userName, link);
        send(toEmail, "Reset your Katixo password", html);
    }

    public void sendAccountApproved(String toEmail, String userName) {
        String html = """
                <h2>Your Katixo account is approved!</h2>
                <p>Hi %s, great news — your account has been approved.</p>
                <p><a href="%s/login">Log in now</a></p>
                """.formatted(userName, baseUrl);
        send(toEmail, "Your Katixo account is approved", html);
    }

    public void sendAccountRejected(String toEmail, String userName, String reason) {
        String html = """
                <h2>Regarding your Katixo account</h2>
                <p>Hi %s, we were unable to activate your account.</p>
                <p><strong>Reason:</strong> %s</p>
                <p>If you have questions, contact us at support@katixo.com</p>
                """.formatted(userName, reason != null ? reason : "Not provided");
        send(toEmail, "Update on your Katixo account", html);
    }

    public void sendAccountSuspended(String toEmail, String userName, String reason) {
        String html = """
                <h2>Your Katixo account has been suspended</h2>
                <p>Hi %s, your account access has been suspended.</p>
                <p><strong>Reason:</strong> %s</p>
                <p>Contact us at support@katixo.com to resolve this.</p>
                """.formatted(userName, reason != null ? reason : "Contact support for details");
        send(toEmail, "Your Katixo account has been suspended", html);
    }

    public void sendAdminPasswordReset(String toEmail, String userName, String tempPassword) {
        String html = """
                <h2>Your password has been reset</h2>
                <p>Hi %s, your Katixo password was reset by the support team.</p>
                <p><strong>Temporary password:</strong> %s</p>
                <p>Please log in and change your password immediately.</p>
                <p><a href="%s/login">Log In</a></p>
                """.formatted(userName, tempPassword, baseUrl);
        send(toEmail, "Your Katixo password was reset", html);
    }

    public void sendNewSignupAlert(String adminEmail, String orgName, String ownerName, String ownerEmail) {
        String html = """
                <h2>New Signup: %s</h2>
                <p>Owner: %s (%s)</p>
                <p><a href="%s">Review in Platform Admin</a></p>
                """.formatted(orgName, ownerName, ownerEmail != null ? ownerEmail : "no email",
                platformAdminUrl + "/pending-approvals");
        send(adminEmail, "New signup: " + orgName, html);
    }

    /**
     * Generic HTML email send — used by the workflow-rules EMAIL action. Same
     * best-effort delivery as the templated helpers (logs + swallows on failure).
     */
    public boolean sendHtml(String to, String subject, String html) {
        return send(to, subject, html);
    }

    /**
     * Best-effort send: returns true on success, false on any failure (logged, not
     * thrown). Callers that care whether delivery happened (e.g. the dunning
     * dispatcher, which must NOT claim a level SENT on a swallowed failure) check
     * the boolean; the fire-and-forget templated helpers ignore it.
     */
    private boolean send(String to, String subject, String html) {
        try {
            MimeMessage message = mailSender.createMimeMessage();
            MimeMessageHelper helper = new MimeMessageHelper(message, true, "UTF-8");
            helper.setFrom(fromName + " <" + fromEmail + ">");
            helper.setTo(to);
            helper.setSubject(subject);
            helper.setText(html, true);
            mailSender.send(message);
            return true;
        } catch (MessagingException e) {
            // MimeMessageHelper.setTo / InternetAddress.parse throw AddressException
            // (a MessagingException) on a malformed recipient.
            log.error("Failed to send email to {}: {}", to, e.getMessage());
            return false;
        } catch (org.springframework.mail.MailException e) {
            // Spring's transport-layer failure is a RuntimeException — honour the
            // documented "logs + swallows" contract instead of propagating.
            log.error("Mail transport failed sending to {}: {}", to, e.getMessage());
            return false;
        }
    }
}
