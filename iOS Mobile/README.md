🔐 LinkedIn OAuth Setup (Required)

This repository integrates LinkedIn OAuth 2.0.
For security reasons, real credentials are NOT included.
You must configure your own LinkedIn keys before running the project.

⸻

📌 What You Need

To use LinkedIn authentication, you must have:
	•	A LinkedIn Developer account
	•	A LinkedIn App
	•	Client ID
	•	Client Secret
	•	Redirect URI

If any of these are missing, authentication will fail.

⸻

🚀 Step 1: Create a LinkedIn Developer App
	1.	Visit: https://www.linkedin.com/developers/
	2.	Create a new application
	3.	Enable the following products:
	•	Sign In with LinkedIn
	•	Share on LinkedIn (only if posting is required)

⸻

🔑 Step 2: Get Your Credentials

From your LinkedIn App dashboard, copy:
	•	Client ID
	•	Client Secret
	•	Redirect URL

⚠️ The redirect URL must exactly match what you configure in code.

Example:

http://localhost:4000/linkedin


⸻

🧩 Step 3: Create LinkedInToken.swift

Inside your project, create a new Swift file:

LinkedInToken.swift

Paste the following code and replace the placeholders with your own values.

import Foundation

struct LinkedInToken: Decodable {
    let access_token: String
    let expires_in: Int
}

enum LinkedIn {
    static let clientId     = "YOUR_LINKEDIN_CLIENT_ID"
    static let clientSecret = "YOUR_LINKEDIN_CLIENT_SECRET"
    static let redirectURI  = "YOUR_REDIRECT_URI"
    static let state        = UUID().uuidString
    static let scope        = "openid profile w_member_social"
}

✅ Once this file is added, LinkedIn authentication is ready to use.

⸻

🛡️ Security Rules (Do Not Skip)
	•	❌ Never commit real client secrets
	•	❌ Never bypass GitHub Push Protection
	•	❌ Never store secrets in public repos

Recommended alternatives:
	•	Environment variables
	•	.xcconfig files (ignored by Git)
	•	Backend token exchange (best practice)

Example:

static let clientSecret = ProcessInfo.processInfo.environment["LINKEDIN_CLIENT_SECRET"] ?? ""


⸻

🔄 OAuth Flow (High-Level)
	1.	User is redirected to LinkedIn authorization
	2.	User grants permission
	3.	LinkedIn redirects back with an authorization code
	4.	Backend exchanges code for an access token
	5.	App uses token for LinkedIn APIs

Tokens expire. Re-authentication is expected.

⸻

❗ Common Issues
	•	Redirect URI mismatch
	•	Incorrect scopes
	•	App not approved for required LinkedIn products

Double-check LinkedIn dashboard settings if auth fails.

⸻

✅ Final Notes

This repository is intentionally safe by default.
If you see placeholders, that is correct behavior.

Add your credentials locally and you are ready to run.
