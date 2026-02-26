// Funções utilitárias usadas em vários lugares do backend

// Gera um código de convite aleatório (6 caracteres)
function generateInviteCode() {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  let code = '';
  for (let i = 0; i < 6; i++) {
    code += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return code;
}

// Formata resposta de sucesso padrão
function successResponse(data, message = 'Sucesso') {
  return {
    success: true,
    message,
    data,
  };
}

// Formata resposta de erro padrão
function errorResponse(message = 'Erro', statusCode = 400) {
  const error = new Error(message);
  error.statusCode = statusCode;
  return error;
}

module.exports = {
  generateInviteCode,
  successResponse,
  errorResponse,
};
