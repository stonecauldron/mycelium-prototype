# Initialize GameAnalytics without a consent prompt

The GameAnalytics SDK already initializes on non-editor builds (itch Web). Their developer policy asks for a first-launch opt-in before any data is sent. For this prototype we keep immediate init and no prompt — we want events as soon as someone plays, and we are not treating itch as a release that needs a privacy wall. Revisit before Steam or any store release.
