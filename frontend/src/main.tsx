import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { BrowserRouter } from 'react-router-dom'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import App from './App'
import { AuthProvider } from './context/AuthContext'
import './styles.css'

const queryClient=new QueryClient({defaultOptions:{queries:{retry:1,staleTime:15_000,refetchOnWindowFocus:false}}})
createRoot(document.getElementById('root')!).render(<StrictMode><QueryClientProvider client={queryClient}><BrowserRouter><AuthProvider><App/></AuthProvider></BrowserRouter></QueryClientProvider></StrictMode>)

if('serviceWorker' in navigator && import.meta.env.PROD){window.addEventListener('load',()=>navigator.serviceWorker.register('/sw.js').catch(()=>undefined))}
