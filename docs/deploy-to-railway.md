# 🚂 **RAILWAY DEPLOYMENT GUIDE** 

## **Step-by-Step Instructions**

### **1. Prepare Your GitHub Repository**

```bash
# Initialize git repository (if not already done)
git init

# Create .gitignore if needed (already created)
# Add all files except config.js (which is already in .gitignore)
git add .

# Commit your code
git commit -m "Initial commit: AI Negotiator Platform with advanced features"

# Create GitHub repository and push
git remote add origin https://github.com/YOUR_USERNAME/roomfinder-ai.git
git branch -M main
git push -u origin main
```

### **2. Set Up Railway Account**

1. Go to **[railway.app](https://railway.app)**
2. Click **"Login with GitHub"**
3. Authorize Railway to access your repositories

### **3. Deploy Your Project**

1. **Create New Project**
   - Click **"New Project"**
   - Select **"Deploy from GitHub repo"**
   - Choose your `roomfinder-ai` repository

2. **Railway will automatically:**
   - Detect your Node.js project
   - Use the `railway.json` configuration
   - Install dependencies from `package.json`
   - Start with `node backend/server.js`

### **4. Configure Environment Variables (OPTIONAL)**

✨ **GOOD NEWS!** Your encrypted config.js file will be automatically decrypted on Railway startup!

**No manual environment variables needed** - the system will use your existing config.js file.

**Optional:** If you want to override any settings, you can add variables in Railway dashboard:

```bash
CONFIG_PASSWORD=nibsaregood  # (optional - uses default if not set)
# Any other overrides if needed...
```

### **5. Deploy and Test**

1. **Automatic Deployment**
   - Railway will automatically build and deploy
   - You'll get a URL like: `https://your-app-name.railway.app`

2. **Test Your Deployment**
   - Visit your Railway URL
   - Test the AI negotiator functionality
   - Verify database connections work
   - Check that environment variables are loaded

## **🔧 Configuration Details**

### **Railway Configuration Files Created:**

1. **`railway.json`** - Railway deployment settings
2. **`package-production.json`** - Production package.json template
3. **`railway-config-template.js`** - Environment variable template

### **Key Features Configured:**

- ✅ **Auto-scaling** - Railway will scale based on traffic
- ✅ **Health checks** - Monitors app health
- ✅ **Restart policy** - Auto-restart on failures  
- ✅ **Environment variables** - Secure API key management
- ✅ **Build optimization** - Efficient deployment process

## **🔒 Security Best Practices**

### **Environment Variables:**
- Never commit API keys to git
- Use Railway's environment variable system
- Config.js is in .gitignore for security

### **Database Security:**
- Supabase Row Level Security (RLS) enabled
- API endpoints validate input
- Secure authentication system

## **📊 Monitoring Your Deployment**

### **Railway Dashboard:**
- **Deployments** - View build logs and status
- **Metrics** - Monitor CPU, memory, requests
- **Logs** - Real-time application logs
- **Variables** - Manage environment variables

### **Application Health:**
- Visit `/api/test-supabase` to test database connection
- Check AI negotiator functionality
- Verify payment processing (in test mode)

## **🚨 Troubleshooting**

### **Common Issues:**

1. **Build Failure:**
   ```bash
   # Check package.json exists in root
   # Verify dependencies are correct
   ```

2. **Environment Variables:**
   ```bash
   # Ensure all required variables are set
   # Check variable names match exactly
   ```

3. **Database Connection:**
   ```bash
   # Verify Supabase URL and keys
   # Check RLS policies are set up
   ```

4. **Port Issues:**
   ```bash
   # Server uses process.env.PORT (already configured)
   ```

## **🎯 Post-Deployment Checklist**

- [ ] App loads successfully at Railway URL
- [ ] Environment variables are working
- [ ] Database connections established
- [ ] AI negotiator responds correctly
- [ ] Real-time updates working
- [ ] Payment system functional (test mode)
- [ ] All pages accessible
- [ ] No console errors

## **🔄 Updates and Redeployment**

```bash
# Make changes to your code
git add .
git commit -m "Update: describe your changes"
git push origin main

# Railway will automatically redeploy!
```

## **💡 Pro Tips**

1. **Custom Domain:**
   - Add your domain in Railway settings
   - Configure DNS to point to Railway

2. **Database Backup:**
   - Supabase provides automatic backups
   - Export important data regularly

3. **Scaling:**
   - Railway auto-scales based on usage
   - Monitor resource usage in dashboard

4. **Logs:**
   - Use Railway logs for debugging
   - Add console.log statements for monitoring

---

## **🎉 Success!**

Your AI Negotiator platform is now live on Railway with:
- ⚡ **Lightning-fast deployment**
- 🔒 **Secure environment variables** 
- 📈 **Auto-scaling capabilities**
- 🛡️ **Built-in monitoring**
- 🔄 **Automatic redeployment**

**Your app will be available at:** `https://your-app-name.railway.app`

---

**Need Help?** 
- Railway docs: [docs.railway.app](https://docs.railway.app)
- GitHub Issues: Create an issue in your repository