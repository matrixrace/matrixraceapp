const { pgTable, serial, varchar, text, timestamp, boolean, integer } = require('drizzle-orm/pg-core');

// Tabela de notícias F1
// Geradas automaticamente a cada 4 horas pelo newsScheduler
const news = pgTable('news', {
  id: serial('id').primaryKey(),
  titleHash: varchar('title_hash', { length: 64 }).unique().notNull(),
  originalTitle: varchar('original_title', { length: 500 }),
  translations: text('translations').notNull(),       // JSON: {"pt": {"title": "...", "summary": "..."}, "en": {...}}
  sourceUrls: text('source_urls').notNull(),           // JSON array: ["https://...", "https://..."]
  sourceNames: varchar('source_names', { length: 500 }),
  imageUrl: text('image_url'),
  category: varchar('category', { length: 50 }),       // race | transfer | technical | regulation | general
  isUpdate: boolean('is_update').default(false),
  parentNewsId: integer('parent_news_id'),
  isPublished: boolean('is_published').default(true),
  publishedAt: timestamp('published_at').notNull(),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow(),
});

module.exports = { news };
