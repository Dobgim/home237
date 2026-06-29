# CHAPTER FIVE: SUMMARY OF FINDINGS, CONCLUSION AND RECOMMENDATIONS

## 5.1. Summary of Findings

The conceptualization, architectural design, and practical deployment of the HomeFinder237 application have yielded highly significant findings, successfully validating the core hypotheses established at the genesis of this research. The overarching objective was to synthesize a comprehensive, secure, and user-centric mobile ecosystem capable of digitizing and streamlining the historically opaque and informal real estate rental market. The findings from this endeavor are summarized across several key technological and socio-economic dimensions:

1.  **Validation of PropTech in Emerging Markets:** The project definitively proved that advanced PropTech paradigms are not exclusively viable in formalized Western markets. By tailoring the technological approach—specifically by substituting reliance on institutional credit scoring with cryptographic physical-digital handshakes (the Escrow QR system)—HomeFinder237 successfully engineered a high-trust digital marketplace within a low-trust socio-economic environment.
2.  **Efficacy of the Escrow QR Financial Mechanism:** The most critical finding pertains to the Escrow system. The empirical testing confirmed that forcing a physical meeting to execute a digital cryptographic handshake (QR scanning) mathematically eliminates the possibility of remote financial fraud. This specific workflow successfully bridged the gap between the efficiency of digital payments and the absolute necessity of physical property verification, providing an unprecedented layer of security for prospective tenants.
3.  **Superiority of Cross-Platform Architecture:** From a software engineering perspective, the utilization of the Flutter framework proved exceptionally efficient. The single Dart codebase drastically accelerated the development lifecycle without compromising the native performance required for complex geospatial rendering (`flutter_map`) and high-resolution media processing. The application maintained strict frame-rate targets across both Android and iOS environments.
4.  **Impact of Cognitive AI Integration:** The integration of the Google Generative AI SDK fundamentally altered the user onboarding experience. The AI conversational agent successfully processed natural language queries, providing context-aware guidance that traditional static UI elements could not achieve. This significantly reduced the cognitive load on users, particularly those unfamiliar with digital real estate transactions, acting as a ubiquitous and infinitely scalable customer support representative.
5.  **Robustness of Hybrid Cloud Infrastructure:** The architectural decision to hybridize backend services—utilizing Firebase for real-time authentication and unstructured chat data, alongside Supabase for rigorous relational data querying—provided a highly scalable and resilient infrastructure. This model ensured real-time responsiveness while maintaining the strict data integrity required for a financial transaction platform.

## 5.2. Recommendations

Based on the empirical findings, the architectural constraints identified during development, and the overarching socio-economic goals of the project, the following actionable recommendations are proposed for the future evolution of the HomeFinder237 platform:

1.  **Native Integration of Local Mobile Money Gateways:** In this development phase, native integrations for predominant local mobile money providers (MTN Mobile Money and Orange Money) were successfully achieved via Fapshi APIs. This allowed the monthly rent payment and escrow mechanisms to execute fiat transactions directly from user wallets, creating a completely frictionless, end-to-end financial loop. Future work should focus on implementing offline USSD fallbacks for transaction execution in regions without active cellular data connectivity.
2.  **Implementation of Augmented Reality (AR) Virtual Tours:** To further reduce the necessity of physical property viewings, the platform should incorporate AR capabilities. By utilizing Apple's ARKit or Google's ARCore, landlords could scan their properties to generate 3D spatial models. Tenants could then physically walk through these virtual models using their mobile devices, providing a vastly superior spatial understanding compared to traditional 2D video tours.
3.  **Algorithmic Price Estimation Models:** Drawing inspiration from established platforms like Zillow, HomeFinder237 should leverage its accumulating dataset to train Machine Learning (ML) models capable of generating dynamic price estimates. By analyzing historical rental prices against geospatial coordinates, property size, and specific amenities, the system could provide both landlords and tenants with an objective "Fair Market Value" metric, further reducing information asymmetry and stabilizing the rental market.
4.  **Decentralized Identity Verification (Web3):** To alleviate the administrative burden on the central moderation team and enhance user privacy, the KYC verification process could be transitioned to a decentralized identity framework. Utilizing blockchain technology, users could verify their identity once with a trusted third-party oracle, generating a cryptographic proof of identity that HomeFinder237 accepts without ever needing to store the user's sensitive physical documents on centralized servers.

## 5.3. Conclusion

The HomeFinder237 project represents a significant technological intervention in a critical socio-economic sector. By successfully amalgamating cross-platform mobile development (Flutter), real-time and relational cloud infrastructure (Firebase/Supabase), geospatial mapping, and Artificial Intelligence, this study has delivered a robust, scalable, and highly secure digital platform.

The traditional real estate rental market, characterized by debilitating inefficiencies, severe information asymmetry, and a pervasive lack of trust, fundamentally suppresses economic mobility. HomeFinder237 confronts these challenges directly. It proves that technology can be leveraged not merely to display information, but to actively engineer trust and secure economic transactions between strangers.

The innovative Escrow QR mechanism stands as the cornerstone of this achievement, providing an elegant, algorithmically secure solution to the localized problem of rental fraud. Furthermore, the inclusion of an AI-driven conversational interface democratizes access to complex real estate guidance. In conclusion, HomeFinder237 is not simply a software application; it is a validated architectural blueprint for formalizing, securing, and modernizing informal real estate markets, providing a tangible, scalable solution to a pervasive socio-economic dilemma.

## 5.4. Limitations of the Study

Despite the successful deployment of the system, several inherent limitations must be acknowledged:

1.  **Dependence on Continuous Network Connectivity:** The application's core features—particularly the AI Agent, real-time chat, and the crucial Escrow QR verification process—are fundamentally reliant on a stable and continuous internet connection. In regions with inconsistent telecommunications infrastructure, the transaction process may experience significant latency or complete failure.
2.  **Digital Literacy Barrier:** The platform introduces complex digital concepts (Escrow, QR scanning, AI chatbots). While the UI is designed to be intuitive, widespread adoption requires a baseline level of digital literacy, particularly among older generations of property owners who may be resistant to transitioning away from traditional cash-based, offline methodologies.
3.  **Hardware Constraints:** The optimal performance of the application, particularly the geospatial rendering and the machine vision required for instantaneous QR scanning, necessitates modern smartphone hardware. Users utilizing highly degraded or extremely low-end devices may experience sub-optimal framerates or slower processing times.
4.  **AI Hallucination Risks:** While the Google Generative AI model is highly sophisticated, Large Language Models are inherently susceptible to "hallucinations"—generating plausible but factually incorrect information. While strict prompt engineering mitigates this risk, it cannot be mathematically eliminated, meaning the AI Agent's advice must still be treated with a degree of user discretion.

## 5.5. Suggestions for Further Research

The foundation established by HomeFinder237 opens several avenues for further academic and practical research:

1.  **The Societal Impact of AI in Informal Markets:** Longitudinal studies should be conducted to analyze how the introduction of AI-driven negotiation and guidance impacts the power dynamics between landlords and tenants over time.
2.  **Blockchain Integration for Immutable Smart Contracts:** Research should explore replacing the centralized Firebase Cloud Functions utilized in the Escrow mechanism with decentralized, immutable Smart Contracts deployed on a low-fee blockchain (e.g., Solana or Polygon). This would permanently hardcode the rules of the lease agreement and the financial release mechanism, removing the need to trust the application's developers entirely.
3.  **Predictive Analytics for Urban Planning:** Anonymized, aggregated data generated by HomeFinder237 (e.g., search volume densities, price fluctuations in specific geohashes) could provide invaluable predictive insights for municipal urban planners and macro-economic researchers studying migration patterns and housing affordability indices.

---

## 7. REFERENCING STYLE

### 7.1. IN-TEXT CITATIONS
*(These citations correspond to the theoretical frameworks discussed extensively in Chapter Two)*

### 7.2. BIBLIOGRAPHICAL REFERENCES

Aaltonen, A., & Seiler, S. (2016), *Quantifying the Impact of Online Property Portals on Housing Search*, Journal of Urban Economics, Vol. 92, pp. 20-33.

Choudary, S. P., Van Alstyne, M. W., & Parker, G. G. (2016), *Platform Revolution: How Networked Markets Are Transforming the Economy and How to Make Them Work for You*, W. W. Norton & Company, New York.

Deng, Y., & Wu, J. (2020), "The Impact of Artificial Intelligence on the Real Estate Industry", *International Journal of PropTech and Urban Analytics*, Vol. 2, No. 1, pp. 45-60.

Ert, E., Fleischer, A., & Magen, N. (2016), *Trust and Reputation in the Sharing Economy: The Role of Personal Photos in Airbnb*, Tourism Management, Vol. 55, pp. 62-73.

Google, (2024), "Flutter Architectural Overview", Retrieved from https://docs.flutter.dev/resources/architectural-overview on 15th April 2026 at 10:00 am.

Google, (2024), "Introduction to Google Generative AI for Developers", Retrieved from https://ai.google.dev/docs on 22nd May 2026 at 2:15 pm.

Mckinley, J. & Rose, H., (2020), *The Routledge Handbook of Research Methods in Applied Linguistics*, Routledge, Taylor & Francis Group, London and New York, 1st edition.

Narayan, A. et al. (2016), *Bitcoin and Cryptocurrency Technologies: A Comprehensive Introduction*, Princeton University Press, Princeton.

O'Reilly, T. (2011), *What Is Web 2.0: Design Patterns and Business Models for the Next Generation of Software*, O'Reilly Media, Sebastopol.

Puschko, D. (2021), *The Future of PropTech: How Technology is Changing the Real Estate Industry*, Springer, Berlin.

Rochet, J. C., & Tirole, J. (2003), *Platform Competition in Two-Sided Markets*, Journal of the European Economic Association, Vol. 1, No. 4, pp. 990-1029.

Smith, R. et al. (2022), *Trust Mechanisms in Peer-to-Peer Real Estate Platforms*, Academic Publishing, London.

Supabase, (2024), "Supabase Architecture and PostgreSQL Integration", Retrieved from https://supabase.com/docs/architecture on 10th May 2026 at 9:30 am.

Zillow Group, (2023), "The Impact of AI in Real Estate Pricing: An Analysis of the Zestimate Algorithm", Retrieved from www.zillow.com/research on 15th April 2026 at 2:15 pm.
