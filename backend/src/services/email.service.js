const nodemailer = require('nodemailer');
const config = require('../config/environment');
const logger = require('../utils/logger');

// Cria o transportador de email usando Gmail
const transporter = nodemailer.createTransport({
  host: config.smtp.host,
  port: config.smtp.port,
  secure: false, // true para 465, false para 587
  auth: {
    user: config.smtp.user,
    pass: config.smtp.pass,
  },
});

// Envia convite para entrar em uma liga
async function sendLeagueInvite({ to, leagueName, invitedByName, inviteLink }) {
  try {
    await transporter.sendMail({
      from: `"F1 Predictions" <${config.smtp.user}>`,
      to,
      subject: `Você foi convidado para a liga "${leagueName}"!`,
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
          <h1 style="color: #E10600;">F1 Predictions</h1>
          <h2>Você foi convidado!</h2>
          <p><strong>${invitedByName}</strong> te convidou para a liga <strong>"${leagueName}"</strong>.</p>
          <p>Faça seus palpites sobre as corridas de Fórmula 1 e dispute com seus amigos!</p>
          <a href="${inviteLink}"
             style="display: inline-block; background-color: #E10600; color: white; padding: 12px 30px;
                    text-decoration: none; border-radius: 5px; margin: 20px 0;">
            Entrar na Liga
          </a>
          <p style="color: #666; font-size: 12px;">
            Se você não esperava este convite, pode ignorar este email.
          </p>
        </div>
      `,
    });

    logger.info(`Email de convite enviado para ${to}`);
    return true;
  } catch (error) {
    logger.error('Erro ao enviar email:', error.message);
    return false;
  }
}

// Envia email de boas-vindas
async function sendWelcomeEmail({ to, displayName }) {
  try {
    await transporter.sendMail({
      from: `"F1 Predictions" <${config.smtp.user}>`,
      to,
      subject: 'Bem-vindo ao F1 Predictions!',
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
          <h1 style="color: #E10600;">F1 Predictions</h1>
          <h2>Bem-vindo, ${displayName || 'Piloto'}!</h2>
          <p>Sua conta foi criada com sucesso.</p>
          <p>Agora você pode:</p>
          <ul>
            <li>Criar ou entrar em ligas</li>
            <li>Fazer palpites sobre as corridas</li>
            <li>Competir com seus amigos</li>
          </ul>
          <p>Boa sorte com seus palpites!</p>
        </div>
      `,
    });

    logger.info(`Email de boas-vindas enviado para ${to}`);
    return true;
  } catch (error) {
    logger.error('Erro ao enviar email de boas-vindas:', error.message);
    return false;
  }
}

module.exports = { sendLeagueInvite, sendWelcomeEmail };
