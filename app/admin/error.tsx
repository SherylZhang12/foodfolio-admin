'use client';
export default function ErrorPage({reset}:{reset:()=>void}){return <main><h1>Let’s reconnect.</h1><p>Admin data could not load. Check your connection and Week 6 database setup.</p><button onClick={reset}>Try again</button></main>;}
