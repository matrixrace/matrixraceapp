// Middleware para verificar se o usuário é administrador
// Deve ser usado APÓS o middleware authenticate
function requireAdmin(req, res, next) {
  if (!req.user) {
    return res.status(401).json({
      success: false,
      message: 'Você precisa estar logado',
    });
  }

  if (!req.user.isAdmin) {
    return res.status(403).json({
      success: false,
      message: 'Acesso negado. Você não é administrador.',
    });
  }

  next();
}

module.exports = { requireAdmin };
