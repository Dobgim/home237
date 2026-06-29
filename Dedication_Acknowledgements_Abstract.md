# DEDICATION

*To every young student or professional who has ever arrived in an unfamiliar city, weary from a long journey, only to find themselves at the mercy of a system designed to exploit rather than to serve — this work is for you.*

*To my family, whose unwavering faith, sacrificial support, and constant encouragement were the bedrock upon which every line of this project was built. Your belief in me never once faltered, even when mine did.*

*And to all the victims of real estate fraud who lost their hard-earned money to ghost landlords and unscrupulous agents — may this work be a small but earnest step toward a future where no one else has to.*

---

# ACKNOWLEDGEMENTS

The successful completion of this project represents the culmination of months of intensive research, engineering, and refinement, and it would not have been possible without the support, guidance, and encouragement of a remarkable circle of people. I wish to express my deepest and most sincere gratitude to each of them.

First and foremost, I am immensely grateful to the **Almighty God**, whose grace, wisdom, and strength sustained me through every late night, every complex bug, and every moment of self-doubt. This project is, first and foremost, a testament to His faithfulness.

I owe an enormous debt of gratitude to my **Supervisor**, whose scholarly guidance, insightful feedback, and patient mentorship were instrumental in shaping this project from a rough concept into a rigorous academic work. Your doors were always open, and your advice was always invaluable. Thank you for challenging me to think deeper and build better.

I extend my profound thanks to the entire **Faculty of the Department of Mathematics and Computer Science** for providing the theoretical foundation and intellectual environment that made this work possible. The knowledge acquired throughout my academic journey here was the scaffolding upon which this project was erected.

To my **classmates and peers** in the 2025/2026 academic cohort — your camaraderie, collaborative spirit, and shared late-night study sessions were a constant source of motivation. The intellectual debates, the shared frustrations, and the collective victories made this journey all the richer.

I am also sincerely grateful to the open-source communities behind **Flutter**, **Firebase**, **Supabase**, and the countless developers who contribute tirelessly to publicly available documentation, tutorials, and forums. Your collective generosity of knowledge is the invisible backbone of modern software development.

Finally, and most profoundly, to my **family** — your unconditional love, patience, and sacrifice cannot be quantified. You provided me not only with material support but with the emotional anchor I needed to persevere. This achievement belongs to you as much as it does to me.

To everyone who played a role, however small, in bringing this vision to life — *thank you*.

---

# ABSTRACT

The real estate rental market in developing regions, particularly in Cameroon, is characterized by pervasive inefficiency, severe information asymmetry, and a chronic lack of institutional trust. Prospective tenants routinely fall victim to sophisticated fraudulent schemes perpetrated by unverified intermediaries, while landlords struggle to market their properties effectively through fragmented and informal channels. The absence of a structured, secure, and centralized digital platform represents a significant and unaddressed market failure that suppresses economic mobility and impedes the formalization of the local housing market.

This study presents **HomeFinder237**, a comprehensive, cross-platform mobile application engineered specifically to address these systemic challenges within the Cameroonian real estate ecosystem. The application is developed using the **Flutter** framework — leveraging a single Dart codebase for simultaneous deployment on Android and iOS — and is powered by a hybrid cloud infrastructure comprising **Firebase** (for real-time authentication, NoSQL data management, and cloud storage) and **Supabase** (for structured relational data querying via PostgreSQL).

The project introduces three primary technological innovations. First, an **interactive Geospatial Property Discovery System** built on the `flutter_map` library, enabling users to visually explore verified property listings using dynamic map-based filtering by location, price, and amenities. Second, and most critically, a novel **QR-Code-Based Escrow Payment Mechanism** is engineered to mathematically eliminate the possibility of remote rental fraud. This system temporarily holds rental funds within a neutral digital escrow, releasing them only upon the successful scanning of a dynamically generated, cryptographically unique QR code during a verified physical meeting between the tenant and landlord — thereby irrevocably linking the digital transaction to a physical confirmation of the property's existence. Third, an **AI-Powered Virtual Assistant**, integrated via the Google Generative AI SDK (Gemini), provides users with 24/7, natural-language-driven customer support, guidance through the rental lifecycle, and real estate advisory services.

The system further implements **Role-Based Access Control (RBAC)**, providing distinct, purpose-built dashboards for three user archetypes: **Tenants** (discovery, payment initiation, tour scheduling), **Landlords** (property ingestion, analytics, revenue management), and **Administrators** (user verification, moderation, and dispute resolution). A **Know Your Customer (KYC)** verification protocol is embedded within the onboarding workflow to establish and maintain a high-trust, authenticated user ecosystem.

The findings of this study validate the central thesis: that advanced PropTech paradigms can be successfully adapted and deployed in low-trust, emerging market environments. The Escrow QR mechanism proved empirically effective in eliminating the primary vector of rental fraud, while the AI integration demonstrably reduced information asymmetry and lowered the barrier to entry for first-time digital real estate users. The application successfully operated across both Android and iOS platforms without performance degradation, confirming the strategic suitability of the Flutter cross-platform architecture.

In conclusion, **HomeFinder237** represents not merely a functional software application, but a validated architectural and socioeconomic blueprint for formalizing informal rental markets through the principled application of mobile technology, artificial intelligence, and secure digital finance.

**Keywords:** *PropTech, Mobile Application, Flutter, Firebase, Supabase, Escrow Payment System, QR Code Verification, Artificial Intelligence, Real Estate, Cameroon, Rental Market, Cross-Platform Development, Digital Trust.*
