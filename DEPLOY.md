# Deploying the backend

Goal: the app works on any phone, anywhere, with your laptop switched off.

Two free services are involved. MongoDB Atlas holds the database; Render runs
the API. Budget about 30 minutes, most of it waiting.

---

## 1. MongoDB Atlas — the database

Your current MongoDB runs on your laptop, so nothing on the internet can reach
it. Atlas replaces it.

1. Sign up at **mongodb.com/atlas** and create a free **M0** cluster.
2. **Database Access** → Add New Database User. Choose a username and password
   and save both — the password goes into a URL later, so avoid `@ : / ? #`
   or you will have to percent-encode them.
3. **Network Access** → Add IP Address → **Allow access from anywhere**
   (`0.0.0.0/0`). Render's outbound IP is not fixed, so restricting by IP will
   simply break the connection.
4. **Connect** → *Drivers* → *Python* → copy the connection string. It looks
   like:

   ```
   mongodb+srv://USER:PASSWORD@cluster0.xxxxx.mongodb.net/?retryWrites=true&w=majority
   ```

   Replace `<password>` with the real password.

---

## 2. GitHub — somewhere for Render to read the code

Render deploys from a Git repository.

```bash
cd C:\clinical-ai
git init
git add .
git commit -m "Clinical AI"
```

Create an empty repository on github.com, then:

```bash
git remote add origin https://github.com/YOUR_NAME/clinical-ai.git
git branch -M main
git push -u origin main
```

**Before pushing, confirm `.env` is not included:**

```bash
git status --short | findstr .env
```

That must print nothing. `.env` holds your `JWT_SECRET` and database password
and is gitignored deliberately. If it appears, stop and remove it:

```bash
git rm --cached .env
```

The four dataset CSVs **should** be included — the deploy builds the model from
them. Confirm:

```bash
git ls-files datasets
```

---

## 3. Render — the API

1. Sign up at **render.com** with your GitHub account.
2. **New → Web Service** → pick your `clinical-ai` repository.
3. Render reads `render.yaml` and fills in most settings. Verify:

   | Setting | Value |
   |---|---|
   | Root Directory | `backend` |
   | Build Command | `pip install -r requirements.txt && python train_model.py --no-plot && python seed_reference_data.py` |
   | Start Command | `uvicorn main:app --host 0.0.0.0 --port $PORT` |
   | Plan | Free |

4. Under **Environment**, add:

   | Key | Value |
   |---|---|
   | `DATABASE_URL` | your Atlas connection string from step 1 |
   | `DATABASE_NAME` | `clinical_ai` |
   | `JWT_SECRET` | click Generate, or paste your own long random string |
   | `DEBUG` | `false` |

5. **Create Web Service.**

The first deploy takes 5–10 minutes. Watch the log: you should see the training
report (41 diseases, 304 rows) and then `Application startup complete.`

You get a URL like `https://clinical-ai-api.onrender.com`. Check it works:

```
https://clinical-ai-api.onrender.com/api/health
```

Both `database` and `prediction_model` should be `true`.

---

## 4. Rebuild the app against the hosted API

```powershell
cd C:\clinical-ai\mobile
flutter build apk --release --target-platform android-arm64 ^
  --dart-define=ENVIRONMENT=prod ^
  --dart-define=API_BASE_URL=https://clinical-ai-api.onrender.com/api
```

Use **https**, and keep the `/api` suffix.

No change is needed to `network_security_config.xml`: it already permits HTTPS
to any host, and blocks only plain HTTP. That restriction is doing its job here.

Install:

```powershell
cd "$env:LOCALAPPDATA\Android\sdk\platform-tools"
.\adb install -r "C:\clinical-ai\mobile\build\app\outputs\flutter-apk\app-release.apk"
```

Now unplug the cable and close every terminal. The app keeps working, and the
same APK works on anyone else's phone.

---

## Things that will surprise you otherwise

**The free tier sleeps.** After about 15 minutes idle, Render stops the
service. The next request wakes it, which takes **around 50 seconds** — during
which the app shows a timeout. It is not broken. Open the health URL in a
browser a minute before demonstrating, and it will be warm. Paid tiers do not
sleep.

**Accounts do not carry over.** The Atlas database is empty and separate from
your laptop's MongoDB, so register again. History from local testing stays
local.

**A new JWT_SECRET invalidates old tokens.** Anyone signed in against the local
backend is signed out. Expected.

**The API URL is compiled into the APK.** Change the URL, rebuild the APK.
Change backend *code* and you only redeploy — every installed phone picks it up
on the next request, no reinstall.

**Redeploying is automatic.** Push to GitHub and Render rebuilds, which
includes retraining the model. If you change `Training.csv`, that is all that is
needed.
