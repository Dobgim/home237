# 📱 **Home237 End-to-End Testing Workflow** 📱

Welcome to the Home237 Beta Test! Our goal is to make renting in Cameroon (the 237!) simple, safe, and modern. 

Please follow this checklist to test the app. There are three main ways to use the app: as a **Tenant** (someone looking for a home), a **Landlord** (someone renting out a home), and an **Admin** (managing the platform).

*If anything breaks, crashes, or looks weird, take a screenshot and note what you were doing!*

---

## ⭐️ Phase 1: First Impressions & Onboarding
*Let's see what happens when a user opens the app for the very first time.*

*   [ ] **Launch:** Open the app. Check the Splash Screen (does the Home237 logo look good?).
*   [ ] **Onboarding:** Swipe through the 3 welcome slides.
*   [ ] **Location Detection:** On the 3rd slide, tap "Detect My Location." Does it find your city? If not, select a city manually from the buttons below.
*   [ ] **Finish Onboarding:** Tap the blue button at the bottom to enter the app.

---

## 👤 Phase 2: Testing as a Tenant
*Pretend you are actively looking for an apartment right now.*

### 1. Account Creation
*   [ ] Go to the Profile tab (bottom right) and tap "Sign In" -> "Sign Up".
*   [ ] Fill in your details. **Make sure you select "Tenant" as your role.**
*   [ ] **Verification:** Check your email for a verification link, click it, and return to the app to Sign In.

### 2. The Home Feed
*   [ ] Look at the top of the Home Feed. Does it say "📍 Near You" with the city you picked during onboarding?
*   [ ] **Filters:** Tap the quick filters at the top (Apartment, Studio, Room, etc.). Does the feed update instantly to match?
*   [ ] **Scroll:** Scroll down. Do you see the "Top Picks" (Featured) section? Do you see the different city lists (Douala, Buea, Yaoundé)?

### 3. Finding a Property
*   [ ] **Explore Tab:** Go to the second tab (the map/list). 
*   [ ] **Search:** Use the search bar to look for a specific town (e.g., "Molyko" or "Bonamoussadi").
*   [ ] **Map:** Tap the "Map" toggle button at the top. Can you see properties on the map?

### 4. Property Details & Actions
*   [ ] Tap on any property to see its full details.
*   [ ] **Photos:** Swipe left/right on the main image to see the gallery.
*   [ ] **Save:** Tap the ❤️ heart icon at the top right.
*   [ ] **Saved Properties:** Go back and check your "Saved" tab (heart icon on bottom bar). Is the property there?

### 5. Contacting the Landlord
*   [ ] Go back to a property detail page.
*   [ ] **Chat:** Tap the "Chat" button. Send a message like "Is this still available?". Does it send successfully?
*   [ ] **Tour Request:** Scroll down and tap "Request Tour". Pick a date and time and submit it.

---

## 🔑 Phase 3: Testing as a Landlord
*Now pretend you own a house and want to put it on Home237.*
*(Tip: Sign out of your Tenant account, and create a brand new account, but this time select "Landlord" as your role).*

### 1. The Landlord Dashboard
*   [ ] Once signed in as a Landlord, does your Home screen look completely different? (It should show statistics and your properties).

### 2. Adding a Property
*   [ ] Tap the **"+" (Add)** button in the middle of the bottom navigation bar.
*   [ ] Fill out the entire form:
    *   Upload 2-3 photos from your phone.
    *   Set the title, price, and exact city/neighborhood.
    *   Select the property type (Apartment, Studio, etc.).
    *   Toggle some amenities (Water, Security, Wi-Fi).
*   [ ] Tap "Submit". *Note: The property will not be public immediately. An Admin has to approve it first.*

### 3. Managing Requests
*   [ ] Go to your **Requests** tab (bell/calendar icon).
*   [ ] Do you see the Tour Request that your Tenant account sent earlier?
*   [ ] Tap on the request. Try to **Accept** or **Reject** it.

### 4. Chatting with Tenants
*   [ ] Go to the **Messages** tab. 
*   [ ] Do you see the message your Tenant sent? Try replying to it.

### 5. Landlord Verification
*   [ ] Go to your Profile tab. 
*   [ ] Look for "Get Verified". Try uploading a fake ID document. Does it submit successfully?

---

## 🛡️ Phase 4: Testing as an Admin
*The boss mode. Contact the developer to manually give your account 'Admin' privileges in the database if you want to test this.*

*   [ ] **Admin Dashboard:** When signed in as an Admin, do you see the Admin stats (Total Users, Pending Properties, etc.)?
*   [ ] **Pending Properties:** Go to the "Properties" section. Find the test property the Landlord just submitted. Review it and tap **Accept**.
*   [ ] **Live Check:** Sign back into the Tenant account. Is the property now visible on the main home feed?
*   [ ] **Verifications:** Go to the "Verifications" section in the Admin panel. Approve the Landlord's fake ID document. The Landlord should now have a blue checkmark next to their name!

---

## 🐞 How to Report Bugs to the Developer
When you find an issue, please send a message to the team in this exact format:

**1. Role:** (Tenant, Landlord, or just browsing)
**2. What I clicked:** (e.g., "I clicked Request Tour")
**3. What happened:** (e.g., "The screen went completely white")
**4. What I expected:** (e.g., "A date picker should have appeared")
**5. Screenshot:** (Attach a screenshot if possible!)

***Thank you so much for testing Home237 and making the Cameroon real estate market better! 🇨🇲***
