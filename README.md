# Controle Fácil

MVP para operação de lanchonetes e trailers: vendas, comandas, delivery, estoque automático, caixa e cardápio digital com QR Code.

## Stack

- Next.js 16, React 19 e TypeScript
- Tailwind CSS
- Supabase Auth, Postgres e Storage
- Vercel

## Desenvolvimento

```bash
cp .env.example .env.local
npm install
npm run dev
```

Variáveis necessárias:

- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`
- `NEXT_PUBLIC_APP_URL` (opcional em desenvolvimento)

## Banco de dados

O esquema versionado está em `supabase/migrations/`. Todas as tabelas expostas possuem RLS habilitado.

## Módulos do MVP

- Login administrativo
- Identidade visual da loja
- Cardápio público e QR Code permanente
- Produtos, categorias, receitas e adicionais
- Pedidos de balcão, mesa e delivery
- Estoque, caixa, produção e relatórios
