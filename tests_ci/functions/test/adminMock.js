/* Mock in-memory untuk firebase-admin: Firestore sederhana + Messaging. */
const state = {
  data: {},      // { koleksi: { docId: {...} } }
  writes: [],    // setiap set() yang dipanggil
  sent: [],      // setiap payload sendEachForMulticast
  reads: [],     // nama koleksi yang dibaca
};

function reset(data) {
  state.data = data || {};
  state.writes = [];
  state.sent = [];
  state.reads = [];
}

function snap(id, d) {
  return {id, exists: d !== undefined, data: () => d};
}

const db = {
  collection(name) {
    const col = () => state.data[name] || {};
    return {
      doc(id) {
        return {
          id,
          async get() {
            state.reads.push(`${name}/${id}`);
            return snap(id, col()[id]);
          },
          async set(value, opts) {
            state.writes.push({collection: name, id, data: value, opts});
          },
        };
      },
      async get() {
        state.reads.push(name);
        const docs = Object.entries(col()).map(([id, d]) => snap(id, d));
        return {docs, empty: docs.length === 0, size: docs.length};
      },
      where(field, op, value) {
        return {
          limit() {
            return {
              async get() {
                state.reads.push(`${name}?${field}${op}${value}`);
                const docs = Object.entries(col())
                  .filter(([, d]) => d && d[field] === value)
                  .map(([id, d]) => snap(id, d));
                return {docs, empty: docs.length === 0, size: docs.length};
              },
            };
          },
        };
      },
    };
  },
};

const firestore = Object.assign(() => db, {
  Timestamp: {fromDate: (date) => ({__timestamp: date})},
  FieldValue: {serverTimestamp: () => "SERVER_TIMESTAMP"},
});

const messaging = () => ({
  async sendEachForMulticast(payload) {
    state.sent.push(payload);
    return {successCount: payload.tokens.length, failureCount: 0, responses: []};
  },
});

module.exports = {
  initializeApp: () => ({}),
  firestore,
  messaging,
  __state: state,
  __reset: reset,
};
