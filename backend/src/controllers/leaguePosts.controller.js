const { pool } = require('../config/database');
const { successResponse, errorResponse } = require('../utils/helpers');

// Verifica se o usuário é membro ativo da liga
async function isMember(leagueId, userId) {
  const res = await pool.query(
    `SELECT 1 FROM league_members WHERE league_id = $1 AND user_id = $2 AND status = 'active'`,
    [leagueId, userId]
  );
  return res.rowCount > 0;
}

// Verifica se o usuário é dono da liga
async function isOwner(leagueId, userId) {
  const res = await pool.query(
    `SELECT 1 FROM leagues WHERE id = $1 AND owner_id = $2`,
    [leagueId, userId]
  );
  return res.rowCount > 0;
}

// ─────────────────────────────────────────────
// GET /leagues/:id/posts
// Lista posts do mural da liga (mais recentes primeiro)
// ─────────────────────────────────────────────
async function getPosts(req, res, next) {
  try {
    const { id: leagueId } = req.params;
    const userId = req.user.id;

    if (!(await isMember(leagueId, userId))) {
      return res.status(403).json(errorResponse('Você não é membro desta liga'));
    }

    const result = await pool.query(
      `SELECT
        p.*,
        u.display_name as author_name,
        u.avatar_url as author_avatar,
        COUNT(DISTINCT pl.id) as likes_count,
        COUNT(DISTINCT pc.id) as comments_count,
        EXISTS(
          SELECT 1 FROM league_post_likes pl2
          WHERE pl2.post_id = p.id AND pl2.user_id = $2
        ) as user_liked,
        CASE WHEN p.type = 'poll' THEN (
          SELECT json_build_object(
            'id', lp.id,
            'question', lp.question,
            'expires_at', lp.expires_at,
            'userVoteOptionId', (
              SELECT option_id FROM league_poll_votes
              WHERE poll_id = lp.id AND user_id = $2
            ),
            'options', (
              SELECT json_agg(json_build_object(
                'id', o.id,
                'text', o.text,
                'orderIndex', o.order_index,
                'voteCount', (
                  SELECT COUNT(*) FROM league_poll_votes v
                  WHERE v.poll_id = lp.id AND v.option_id = o.id
                )
              ) ORDER BY o.order_index)
              FROM league_poll_options o WHERE o.poll_id = lp.id
            ),
            'totalVotes', (
              SELECT COUNT(*) FROM league_poll_votes WHERE poll_id = lp.id
            )
          )
          FROM league_polls lp WHERE lp.post_id = p.id
        ) ELSE NULL END as poll
       FROM league_posts p
       JOIN users u ON u.id = p.user_id
       LEFT JOIN league_post_likes pl ON pl.post_id = p.id
       LEFT JOIN league_post_comments pc ON pc.post_id = p.id
       WHERE p.league_id = $1
       GROUP BY p.id, u.display_name, u.avatar_url
       ORDER BY p.is_pinned DESC, p.created_at DESC`,
      [leagueId, userId]
    );

    res.json(successResponse(result.rows));
  } catch (error) {
    next(error);
  }
}

// ─────────────────────────────────────────────
// POST /leagues/:id/posts
// Cria um post de texto ou enquete
// ─────────────────────────────────────────────
async function createPost(req, res, next) {
  try {
    const { id: leagueId } = req.params;
    const userId = req.user.id;
    const { type = 'text', content, poll } = req.body;

    if (!(await isMember(leagueId, userId))) {
      return res.status(403).json(errorResponse('Você não é membro desta liga'));
    }

    // Verifica post_mode
    const leagueRes = await pool.query(
      `SELECT post_mode, owner_id FROM leagues WHERE id = $1`,
      [leagueId]
    );
    if (!leagueRes.rows[0]) return res.status(404).json(errorResponse('Liga não encontrada'));

    const { post_mode, owner_id } = leagueRes.rows[0];
    const owner = await isOwner(leagueId, userId);

    if (post_mode === 'leader_only' && !owner) {
      return res.status(403).json(errorResponse('Apenas o líder pode postar nesta liga'));
    }

    // Enquetes só o líder pode criar
    if (type === 'poll' && !owner) {
      return res.status(403).json(errorResponse('Apenas o líder pode criar enquetes'));
    }

    if (type === 'text') {
      if (!content || content.trim().length === 0) {
        return res.status(400).json(errorResponse('Conteúdo do post é obrigatório'));
      }

      const postRes = await pool.query(
        `INSERT INTO league_posts (league_id, user_id, type, content)
         VALUES ($1, $2, 'text', $3) RETURNING *`,
        [leagueId, userId, content.trim()]
      );

      const post = postRes.rows[0];
      const userRes = await pool.query(
        `SELECT display_name, avatar_url FROM users WHERE id = $1`,
        [userId]
      );
      return res.status(201).json(successResponse({
        ...post,
        author_name: userRes.rows[0]?.display_name,
        author_avatar: userRes.rows[0]?.avatar_url,
        likes_count: 0,
        comments_count: 0,
        user_liked: false,
      }));
    }

    if (type === 'poll') {
      if (!poll || !poll.question || !Array.isArray(poll.options) || poll.options.length < 2) {
        return res.status(400).json(errorResponse('Enquete precisa de pergunta e ao menos 2 opções'));
      }

      const client = await pool.connect();
      try {
        await client.query('BEGIN');

        const postRes = await client.query(
          `INSERT INTO league_posts (league_id, user_id, type)
           VALUES ($1, $2, 'poll') RETURNING *`,
          [leagueId, userId]
        );
        const post = postRes.rows[0];

        const pollRes = await client.query(
          `INSERT INTO league_polls (post_id, question, expires_at)
           VALUES ($1, $2, $3) RETURNING *`,
          [post.id, poll.question.trim(), poll.expiresAt || null]
        );
        const createdPoll = pollRes.rows[0];

        const optionPromises = poll.options.map((opt, idx) =>
          client.query(
            `INSERT INTO league_poll_options (poll_id, text, order_index) VALUES ($1, $2, $3) RETURNING *`,
            [createdPoll.id, opt.trim(), idx]
          )
        );
        const optionResults = await Promise.all(optionPromises);
        const options = optionResults.map((r) => r.rows[0]);

        await client.query('COMMIT');

        const userRes = await pool.query(
          `SELECT display_name, avatar_url FROM users WHERE id = $1`,
          [userId]
        );

        return res.status(201).json(successResponse({
          ...post,
          author_name: userRes.rows[0]?.display_name,
          author_avatar: userRes.rows[0]?.avatar_url,
          likes_count: 0,
          comments_count: 0,
          user_liked: false,
          poll: {
            ...createdPoll,
            options: options.map((o) => ({ ...o, voteCount: 0 })),
            totalVotes: 0,
            userVoteOptionId: null,
          },
        }));
      } catch (err) {
        await client.query('ROLLBACK');
        throw err;
      } finally {
        client.release();
      }
    }

    return res.status(400).json(errorResponse('Tipo de post inválido'));
  } catch (error) {
    next(error);
  }
}

// ─────────────────────────────────────────────
// DELETE /leagues/:id/posts/:postId
// Apaga um post (autor ou líder)
// ─────────────────────────────────────────────
async function deletePost(req, res, next) {
  try {
    const { id: leagueId, postId } = req.params;
    const userId = req.user.id;

    const postRes = await pool.query(
      `SELECT user_id FROM league_posts WHERE id = $1 AND league_id = $2`,
      [postId, leagueId]
    );
    if (!postRes.rows[0]) return res.status(404).json(errorResponse('Post não encontrado'));

    const isAuthor = postRes.rows[0].user_id === userId;
    const owner = await isOwner(leagueId, userId);

    if (!isAuthor && !owner) {
      return res.status(403).json(errorResponse('Sem permissão para apagar este post'));
    }

    await pool.query(`DELETE FROM league_posts WHERE id = $1`, [postId]);
    res.json(successResponse({ message: 'Post apagado' }));
  } catch (error) {
    next(error);
  }
}

// ─────────────────────────────────────────────
// POST /leagues/:id/posts/:postId/like
// Toggle curtida
// ─────────────────────────────────────────────
async function toggleLike(req, res, next) {
  try {
    const { id: leagueId, postId } = req.params;
    const userId = req.user.id;

    if (!(await isMember(leagueId, userId))) {
      return res.status(403).json(errorResponse('Você não é membro desta liga'));
    }

    const existing = await pool.query(
      `SELECT id FROM league_post_likes WHERE post_id = $1 AND user_id = $2`,
      [postId, userId]
    );

    if (existing.rowCount > 0) {
      await pool.query(
        `DELETE FROM league_post_likes WHERE post_id = $1 AND user_id = $2`,
        [postId, userId]
      );
      res.json(successResponse({ liked: false }));
    } else {
      await pool.query(
        `INSERT INTO league_post_likes (post_id, user_id) VALUES ($1, $2)`,
        [postId, userId]
      );
      res.json(successResponse({ liked: true }));
    }
  } catch (error) {
    next(error);
  }
}

// ─────────────────────────────────────────────
// GET /leagues/:id/posts/:postId/comments
// ─────────────────────────────────────────────
async function getComments(req, res, next) {
  try {
    const { id: leagueId, postId } = req.params;
    const userId = req.user.id;

    if (!(await isMember(leagueId, userId))) {
      return res.status(403).json(errorResponse('Você não é membro desta liga'));
    }

    const result = await pool.query(
      `SELECT c.*, u.display_name as author_name, u.avatar_url as author_avatar
       FROM league_post_comments c
       JOIN users u ON u.id = c.user_id
       WHERE c.post_id = $1
       ORDER BY c.created_at ASC`,
      [postId]
    );

    res.json(successResponse(result.rows));
  } catch (error) {
    next(error);
  }
}

// ─────────────────────────────────────────────
// POST /leagues/:id/posts/:postId/comments
// ─────────────────────────────────────────────
async function addComment(req, res, next) {
  try {
    const { id: leagueId, postId } = req.params;
    const userId = req.user.id;
    const { content } = req.body;

    if (!content || content.trim().length === 0) {
      return res.status(400).json(errorResponse('Comentário não pode ser vazio'));
    }

    if (!(await isMember(leagueId, userId))) {
      return res.status(403).json(errorResponse('Você não é membro desta liga'));
    }

    const result = await pool.query(
      `INSERT INTO league_post_comments (post_id, user_id, content)
       VALUES ($1, $2, $3) RETURNING *`,
      [postId, userId, content.trim()]
    );

    const userRes = await pool.query(
      `SELECT display_name, avatar_url FROM users WHERE id = $1`,
      [userId]
    );

    res.status(201).json(successResponse({
      ...result.rows[0],
      author_name: userRes.rows[0]?.display_name,
      author_avatar: userRes.rows[0]?.avatar_url,
    }));
  } catch (error) {
    next(error);
  }
}

// ─────────────────────────────────────────────
// DELETE /leagues/:id/posts/:postId/comments/:commentId
// ─────────────────────────────────────────────
async function deleteComment(req, res, next) {
  try {
    const { id: leagueId, postId, commentId } = req.params;
    const userId = req.user.id;

    const commentRes = await pool.query(
      `SELECT user_id FROM league_post_comments WHERE id = $1 AND post_id = $2`,
      [commentId, postId]
    );
    if (!commentRes.rows[0]) return res.status(404).json(errorResponse('Comentário não encontrado'));

    const isAuthor = commentRes.rows[0].user_id === userId;
    const owner = await isOwner(leagueId, userId);

    if (!isAuthor && !owner) {
      return res.status(403).json(errorResponse('Sem permissão para apagar este comentário'));
    }

    await pool.query(`DELETE FROM league_post_comments WHERE id = $1`, [commentId]);
    res.json(successResponse({ message: 'Comentário apagado' }));
  } catch (error) {
    next(error);
  }
}

// ─────────────────────────────────────────────
// POST /leagues/:id/polls/:pollId/vote
// Votar ou trocar voto em enquete
// ─────────────────────────────────────────────
async function votePoll(req, res, next) {
  try {
    const { id: leagueId, pollId } = req.params;
    const userId = req.user.id;
    const { optionId } = req.body;

    if (!(await isMember(leagueId, userId))) {
      return res.status(403).json(errorResponse('Você não é membro desta liga'));
    }

    // Verifica se a enquete existe e não expirou
    const pollRes = await pool.query(
      `SELECT lp.id, lp.expires_at FROM league_polls lp
       JOIN league_posts p ON p.id = lp.post_id
       WHERE lp.id = $1 AND p.league_id = $2`,
      [pollId, leagueId]
    );
    if (!pollRes.rows[0]) return res.status(404).json(errorResponse('Enquete não encontrada'));

    const { expires_at } = pollRes.rows[0];
    if (expires_at && new Date(expires_at) < new Date()) {
      return res.status(400).json(errorResponse('Esta enquete já encerrou'));
    }

    // Verifica se a opção pertence à enquete
    const optRes = await pool.query(
      `SELECT id FROM league_poll_options WHERE id = $1 AND poll_id = $2`,
      [optionId, pollId]
    );
    if (!optRes.rows[0]) return res.status(404).json(errorResponse('Opção inválida'));

    // Insere ou atualiza o voto
    await pool.query(
      `INSERT INTO league_poll_votes (poll_id, option_id, user_id)
       VALUES ($1, $2, $3)
       ON CONFLICT (poll_id, user_id) DO UPDATE SET option_id = $2`,
      [pollId, optionId, userId]
    );

    // Retorna contagem atualizada
    const countsRes = await pool.query(
      `SELECT o.id, o.text, o.order_index,
        COUNT(v.id) as vote_count
       FROM league_poll_options o
       LEFT JOIN league_poll_votes v ON v.option_id = o.id AND v.poll_id = $1
       WHERE o.poll_id = $1
       GROUP BY o.id
       ORDER BY o.order_index`,
      [pollId]
    );

    const totalRes = await pool.query(
      `SELECT COUNT(*) as total FROM league_poll_votes WHERE poll_id = $1`,
      [pollId]
    );

    res.json(successResponse({
      options: countsRes.rows,
      totalVotes: parseInt(totalRes.rows[0].total),
      userVoteOptionId: optionId,
    }));
  } catch (error) {
    next(error);
  }
}

// ─────────────────────────────────────────────
// PUT /leagues/:id/post-settings
// Altera post_mode da liga (só líder)
// ─────────────────────────────────────────────
async function updatePostSettings(req, res, next) {
  try {
    const { id: leagueId } = req.params;
    const userId = req.user.id;
    const { postMode } = req.body;

    if (!['all', 'leader_only'].includes(postMode)) {
      return res.status(400).json(errorResponse('post_mode inválido'));
    }

    if (!(await isOwner(leagueId, userId))) {
      return res.status(403).json(errorResponse('Apenas o líder pode alterar as configurações'));
    }

    await pool.query(
      `UPDATE leagues SET post_mode = $1 WHERE id = $2`,
      [postMode, leagueId]
    );

    res.json(successResponse({ postMode }));
  } catch (error) {
    next(error);
  }
}

// ─────────────────────────────────────────────
// GET /leagues/:id/highlights
// Retorna: melhor da última rodada + próxima corrida
// ─────────────────────────────────────────────
async function getHighlights(req, res, next) {
  try {
    const { id: leagueId } = req.params;
    const userId = req.user.id;

    if (!(await isMember(leagueId, userId))) {
      return res.status(403).json(errorResponse('Você não é membro desta liga'));
    }

    // Próxima corrida com prazo de palpite + status do palpite do usuário
    const nextRaceRes = await pool.query(
      `SELECT r.id, r.name, r.round, r.fp1_date, r.qualifying_date, r.race_date,
              r.circuit_name, r.location,
              EXISTS(
                SELECT 1 FROM predictions p
                WHERE p.user_id = $2 AND p.race_id = r.id
              ) as has_prediction,
              EXISTS(
                SELECT 1 FROM prediction_applications pa
                WHERE pa.user_id = $2 AND pa.race_id = r.id AND pa.league_id = $1
              ) as prediction_applied
       FROM races r
       JOIN league_races lr ON lr.race_id = r.id
       WHERE lr.league_id = $1
         AND r.is_completed = false
         AND r.race_date > NOW()
       ORDER BY r.race_date ASC
       LIMIT 1`,
      [leagueId, userId]
    );

    // Melhor da última rodada concluída
    const bestLastRaceRes = await pool.query(
      `SELECT s.points, s.race_id, u.display_name, u.avatar_url, r.name as race_name
       FROM scores s
       JOIN users u ON u.id = s.user_id
       JOIN races r ON r.id = s.race_id
       JOIN league_races lr ON lr.race_id = s.race_id AND lr.league_id = s.league_id
       WHERE s.league_id = $1
         AND r.is_completed = true
         AND s.race_id = (
           SELECT lr2.race_id FROM league_races lr2
           JOIN races r2 ON r2.id = lr2.race_id
           WHERE lr2.league_id = $1 AND r2.is_completed = true
           ORDER BY r2.race_date DESC
           LIMIT 1
         )
       ORDER BY s.points DESC
       LIMIT 1`,
      [leagueId]
    );

    res.json(successResponse({
      nextRace: nextRaceRes.rows[0] || null,
      bestLastRace: bestLastRaceRes.rows[0] || null,
    }));
  } catch (error) {
    next(error);
  }
}

// ─────────────────────────────────────────────
// GET /leagues/:id/predictions-revealed/:raceId
// Palpites de todos os membros para uma corrida (só após lock)
// ─────────────────────────────────────────────
async function getPredictionsRevealed(req, res, next) {
  try {
    const { id: leagueId, raceId } = req.params;
    const userId = req.user.id;

    if (!(await isMember(leagueId, userId))) {
      return res.status(403).json(errorResponse('Você não é membro desta liga'));
    }

    // Verifica se o prazo já passou (usa fp1_date como primeiro lock, se disponível)
    const raceRes = await pool.query(
      `SELECT fp1_date, qualifying_date, race_date FROM races WHERE id = $1`,
      [raceId]
    );
    if (!raceRes.rows[0]) return res.status(404).json(errorResponse('Corrida não encontrada'));

    const { fp1_date, qualifying_date, race_date } = raceRes.rows[0];
    const lockDate = fp1_date || qualifying_date || race_date;

    if (new Date(lockDate) > new Date()) {
      return res.status(403).json(errorResponse('Os palpites ainda não foram revelados. Aguarde o prazo passar.'));
    }

    // Busca palpites de todos os membros ativos
    const result = await pool.query(
      `SELECT u.id as user_id, u.display_name, u.avatar_url,
        json_agg(
          json_build_object(
            'position', p.predicted_position,
            'driverName', d.first_name || ' ' || d.last_name,
            'driverNumber', d.number
          ) ORDER BY p.predicted_position
        ) as predictions
       FROM league_members lm
       JOIN users u ON u.id = lm.user_id
       LEFT JOIN predictions p ON p.user_id = lm.user_id AND p.race_id = $2
       LEFT JOIN drivers d ON d.id = p.driver_id
       WHERE lm.league_id = $1 AND lm.status = 'active'
       GROUP BY u.id, u.display_name, u.avatar_url
       ORDER BY u.display_name`,
      [leagueId, raceId]
    );

    res.json(successResponse(result.rows));
  } catch (error) {
    next(error);
  }
}

module.exports = {
  getPosts,
  createPost,
  deletePost,
  toggleLike,
  getComments,
  addComment,
  deleteComment,
  votePoll,
  updatePostSettings,
  getHighlights,
  getPredictionsRevealed,
};
