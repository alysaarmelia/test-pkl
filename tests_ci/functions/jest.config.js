/** Konfigurasi Jest untuk uji logika Cloud Functions (offline, tanpa emulator). */
module.exports = {
  testEnvironment: "node",
  silent: true, // log console.log dari functions/src tidak ditampilkan
  roots: ["<rootDir>/test"],
  testMatch: ["**/*.test.ts"],
  transform: {
    "^.+\\.ts$": ["ts-jest", {tsconfig: "<rootDir>/tsconfig.json", diagnostics: false, isolatedModules: true}],
  },
  // firebase-admin diganti mock in-memory (tidak ada sambungan ke Firebase mana pun).
  // Modul firebase-functions v2 diarahkan ke salinan di tests_ci/functions/node_modules agar
  // pengujian tidak bergantung pada ada/tidaknya functions/node_modules di repo.
  moduleNameMapper: {
    "^firebase-admin$": "<rootDir>/test/adminMock.js",
    "^firebase-functions/v2/(https|firestore|scheduler)$":
      "<rootDir>/node_modules/firebase-functions/lib/v2/providers/$1.js",
  },
  modulePaths: ["<rootDir>/node_modules"],
  reporters: [
    "default",
    ["jest-junit", {
      outputDirectory: "<rootDir>/../results",
      outputName: "functions-junit.xml",
      classNameTemplate: "{classname}",
      titleTemplate: "{title}",
      suiteName: "Cloud Functions (logika offline)",
    }],
  ],
};
