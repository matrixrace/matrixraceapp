const router = require('express').Router();
const { getNews, getNewsById } = require('../controllers/news.controller');

// Rotas públicas (não requerem autenticação)
router.get('/', getNews);
router.get('/:id', getNewsById);

module.exports = router;
