const DB_NAME = "kv";
const STORE_NAME = "kv";

let db: Promise<IDBDatabase> | null = null;

function open() {
  return (db ??= new Promise<IDBDatabase>((resolve, reject) => {
    const req = indexedDB.open(DB_NAME, 1);
    req.onupgradeneeded = () => req.result.createObjectStore(STORE_NAME);
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => ((db = null), reject(req.error));
  }));
}

function run<T>(mode: IDBTransactionMode, fn: (store: IDBObjectStore) => IDBRequest<T>): Promise<T> {
  return open().then(
    (db) =>
      new Promise((resolve, reject) => {
        const req = fn(db.transaction(STORE_NAME, mode).objectStore(STORE_NAME));
        req.onsuccess = () => resolve(req.result);
        req.onerror = () => reject(req.error);
      }),
  );
}

export function persistent<T>(key: string) {
  return open().then(() => ({
    delete: () => run("readwrite", (s) => s.delete(key)),
    get: () => run<T | undefined>("readonly", (s) => s.get(key)),
    set: (value: T) => run("readwrite", (s) => s.put(value, key)).then(() => {}),
  }));
}
