# WhiteBox Giftworks Private RMOS Dashboard

This repository contains the private relationship management operating system (RMOS) dashboard for WhiteBox Giftworks. It runs independently on port `5174` during local development.

---

## Directory Structure

```
whitebox-dashboard/
├── package.json         # Project metadata and run scripts
├── vite.config.js       # Vite configuration for the dashboard
├── README.md            # Setup and developer guide (this file)
├── .gitignore           # Git ignore file for secrets and dependencies
├── index.html           # Main dashboard app layout
├── main-dashboard-v34.js# Client-side operational dashboard scripts and handlers
├── spend-ledger-modal.js# Interactive budget ledger components
├── style-dashboard.css  # Core dashboard stylesheet
├── style-v10-dashboard.css # Premium dark and layout dashboard styles
├── assets/              # Dashboard brand assets (crm-logo, loading-logo)
└── SUPABASE-MIGRATION-AUDIT/ # Database and Auth migration documentation
```

---

## Getting Started

### Prerequisites
Make sure you have [Node.js](https://nodejs.org/) installed (LTS version is recommended).

### 1. Installation
Install the development dependencies:
```bash
npm install
```

### 2. Run Locally (Development Server)
To start the Vite development server on port `5174`, run:
```bash
npm run dev
```
Open [http://localhost:5174](http://localhost:5174) in your browser.

---

## Route Protection & Login Redirection

*   **Role Protection Gate**: The dashboard checks `localStorage.getItem('whitebox_role')` on load.
*   **Redirect Logic**: If no user role is saved (user is not logged in), the browser is automatically redirected back to the marketing site's login page:
    *   If running on `localhost`, it redirects to `http://localhost:5173/login.html`.
    *   If running in production (`dashboard.whiteboxworks.com`), it redirects to `https://whiteboxworks.com/login.html`.
