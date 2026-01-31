# Hanabi Download Manager X - Official Website

Official website and landing page for Hanabi Download Manager X.

## Tech Stack

- **React 18** - UI framework
- **TypeScript** - Type safety
- **Vite** - Build tool and dev server
- **Tailwind CSS** - Utility-first CSS framework
- **React Router** - Client-side routing
- **i18next** - Internationalization (English/Chinese)

## Features

- Modern, responsive landing page
- Multi-language support (EN/ZH)
- Feature showcase
- Download section
- Comparison with competitors
- Legal pages (Privacy Policy, Terms of Service)
- Announcements system
- Admin dashboard for announcements

## Project Structure

```
x.zzbuaoye.top/
├── src/
│   ├── components/        # React components
│   │   ├── Header.tsx
│   │   ├── Hero.tsx
│   │   ├── Features.tsx
│   │   ├── Comparison.tsx
│   │   ├── Download.tsx
│   │   └── Footer.tsx
│   ├── pages/            # Page components
│   │   ├── AdminLogin.tsx
│   │   ├── AdminDashboard.tsx
│   │   ├── Announcements.tsx
│   │   ├── PrivacyPolicy.tsx
│   │   ├── TermsOfService.tsx
│   │   └── NotFound.tsx
│   ├── services/         # API services
│   ├── i18n/            # Internationalization
│   │   └── locales/
│   │       ├── en.json
│   │       └── zh.json
│   ├── App.tsx
│   └── main.tsx
├── public/              # Static assets
├── deploy/             # Deployment scripts
└── docs/               # Documentation

```

## Development

### Prerequisites

- Node.js 18+
- npm or yarn

### Setup

```bash
# Install dependencies
npm install

# Start dev server
npm run dev

# Build for production
npm run build

# Preview production build
npm run preview
```

### Environment Variables

Create `.env` file:

```env
VITE_API_BASE_URL=https://api.example.com
```

## Deployment

### Quick Deploy

```bash
# Build
npm run build

# Deploy to server
cd deploy
./quick-deploy.sh
```

### Docker Deploy

```bash
cd deploy
docker-compose up -d
```

See [deploy/README.md](deploy/README.md) for detailed deployment instructions.

## Pages

- **/** - Home/Landing page
- **/announcements** - Announcements list
- **/privacy** - Privacy Policy
- **/terms** - Terms of Service
- **/admin** - Admin login
- **/admin/dashboard** - Admin dashboard (protected)

## Features

### Landing Page
- Hero section with CTA
- Feature highlights
- Comparison table
- Download section
- Footer with links

### Announcements System
- Public announcements page
- Admin dashboard for management
- Create/edit/delete announcements
- Priority levels
- Expiration dates

### Internationalization
- English and Chinese support
- Language switcher in header
- Persistent language preference

### Admin Dashboard
- Protected routes
- Announcement management
- Statistics overview
- User-friendly interface

## API Integration

The website integrates with backend APIs:

- Announcements API
- Statistics API
- Admin authentication

See [docs/API.md](docs/API.md) for API documentation.

## Styling

Uses Tailwind CSS with custom configuration:

- Custom color palette
- Responsive breakpoints
- Dark mode support (planned)
- Fluent Design inspired components

## Browser Support

- Chrome/Edge (latest)
- Firefox (latest)
- Safari (latest)

## Contributing

1. Fork the repository
2. Create feature branch
3. Make changes
4. Test thoroughly
5. Submit pull request

## License

Part of Hanabi Download Manager X project.

Copyright © ZZBuAoYe 2026

## Links

- Main Project: [Hanabi Download Manager X](https://github.com/zzbuaoye/hanabi-download-manager-x)
- Website: [https://x.zzbuaoye.top](https://x.zzbuaoye.top)
- Statistics: [https://online.zzbuaoye.top](https://online.zzbuaoye.top)
