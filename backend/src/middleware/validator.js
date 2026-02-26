const { ZodError } = require('zod');

// Middleware de validação usando Zod
// Recebe um schema Zod e valida o body da requisição
function validate(schema) {
  return (req, res, next) => {
    try {
      // Valida os dados recebidos
      const validated = schema.parse(req.body);
      req.body = validated; // Substitui com dados limpos/validados
      next();
    } catch (error) {
      if (error instanceof ZodError) {
        // Formata os erros de validação de forma amigável
        const errors = error.errors.map((e) => ({
          campo: e.path.join('.'),
          mensagem: e.message,
        }));

        return res.status(400).json({
          success: false,
          message: 'Dados inválidos',
          errors,
        });
      }

      next(error);
    }
  };
}

module.exports = { validate };
