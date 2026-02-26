const { db } = require('../config/database');
const { notifications } = require('../db/schema');
const { eq, and, desc } = require('drizzle-orm');
const { successResponse, errorResponse } = require('../utils/helpers');

// GET /api/v1/notifications
// Lista as notificações do usuário logado (mais recentes primeiro)
async function getNotifications(req, res, next) {
  try {
    const userNotifications = await db
      .select()
      .from(notifications)
      .where(eq(notifications.userId, req.user.id))
      .orderBy(desc(notifications.createdAt))
      .limit(50);

    const unreadCount = userNotifications.filter(n => !n.isRead).length;

    res.json(successResponse({ notifications: userNotifications, unreadCount }));
  } catch (error) {
    next(error);
  }
}

// PUT /api/v1/notifications/:id/read
// Marca uma notificação como lida
async function markAsRead(req, res, next) {
  try {
    const { id } = req.params;

    const [notification] = await db
      .select()
      .from(notifications)
      .where(eq(notifications.id, id))
      .limit(1);

    if (!notification) {
      return next(errorResponse('Notificação não encontrada', 404));
    }

    if (notification.userId !== req.user.id) {
      return next(errorResponse('Sem permissão', 403));
    }

    await db
      .update(notifications)
      .set({ isRead: true })
      .where(eq(notifications.id, id));

    res.json(successResponse(null, 'Notificação marcada como lida'));
  } catch (error) {
    next(error);
  }
}

// PUT /api/v1/notifications/read-all
// Marca todas as notificações do usuário como lidas
async function markAllAsRead(req, res, next) {
  try {
    await db
      .update(notifications)
      .set({ isRead: true })
      .where(
        and(
          eq(notifications.userId, req.user.id),
          eq(notifications.isRead, false)
        )
      );

    res.json(successResponse(null, 'Todas as notificações marcadas como lidas'));
  } catch (error) {
    next(error);
  }
}

module.exports = { getNotifications, markAsRead, markAllAsRead };
