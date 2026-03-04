const { Router } = require('express');
const {
  createGroup,
  getMyGroups,
  getGroupDetails,
  updateGroup,
  addMembers,
  removeMember,
  getGroupMessages,
} = require('../controllers/chatGroups.controller');
const { authenticate } = require('../middleware/auth');

const router = Router();

// Todas as rotas exigem autenticação
router.use(authenticate);

// CRUD de grupos
router.post('/', createGroup);
router.get('/', getMyGroups);
router.get('/:groupId', getGroupDetails);
router.put('/:groupId', updateGroup);

// Membros
router.post('/:groupId/members', addMembers);
router.delete('/:groupId/members/:userId', removeMember);

// Mensagens do grupo
router.get('/:groupId/messages', getGroupMessages);

module.exports = router;
