import "dotenv/config";
import { Client } from "pg";
import { backOff } from "exponential-backoff";
import express from "express";
import waitOn from "wait-on";
import onExit from "signal-exit";
import cors from "cors";

// Add your routes here
const setupApp = (client: Client): express.Application => {
  const app: express.Application = express();

  app.use(cors());

  app.use(express.json());

  // get the components from the backend
  app.get("/components", async (_req, res) => {
    const { rows } = await client.query(`SELECT * FROM components`);
    res.json(rows);
  });

  // get the components properties from the backend
  app.get("/components/:id/properties", async (req, res) => {
    const { id } = req.params;
    const result = await client.query(
      "SELECT * FROM properties WHERE component_id = $1",
      [id]
    );
    res.json(result.rows[0]);
  });

  // update the components properties from the backend depending on what was changed
  app.patch("/components/:id/properties", async (req, res) => {
    const { id } = req.params;
    const {
      margin_top,
      margin_bottom,
      margin_left,
      margin_right,
      padding_top,
      padding_bottom,
      padding_left,
      padding_right,
    } = req.body;

    const values: (string | number)[] = [];
    let updates: string[] = [];

    // helper function to check if a side to be updated or not
    const addUpdate = (column: string, value: string) => {
      if (value !== undefined) {
        updates.push(`${column} = $${values.length + 1}`);
        values.push(value ?? "auto");
      }
    };

    addUpdate("margin_top", margin_top);
    addUpdate("margin_bottom", margin_bottom);
    addUpdate("margin_left", margin_left);
    addUpdate("margin_right", margin_right);

    addUpdate("padding_top", padding_top);
    addUpdate("padding_bottom", padding_bottom);
    addUpdate("padding_left", padding_left);
    addUpdate("padding_right", padding_right);

    if (updates.length === 0) {
      return res.status(400).json({ error: "No properties to update." });
    }

    const sql = `
      UPDATE properties 
      SET ${updates.join(", ")} 
      WHERE component_id = $${values.length + 1} 
      RETURNING *`;

    values.push(+id);

    try {
      const result = await client.query(sql, values);
      res.json(result.rows[0]);
    } catch (error) {
      console.error(error);
      res.status(500).json({ error: "Failed to update properties." });
    }
  });

  return app;
};

// Waits for the database to start and connects
const connect = async (): Promise<Client> => {
  console.log("Connecting");
  const resource = `tcp:${process.env.PGHOST}:${process.env.PGPORT}`;
  console.log(`Waiting for ${resource}`);
  await waitOn({ resources: [resource] });
  console.log("Initializing client");
  const client = new Client();
  await client.connect();
  console.log("Connected to database");

  // Ensure the client disconnects on exit
  onExit(async () => {
    console.log("onExit: closing client");
    await client.end();
  });

  return client;
};

const main = async () => {
  const client = await connect();
  const app = setupApp(client);
  const port = parseInt(process.env.SERVER_PORT);
  app.listen(port, () => {
    console.log(
      `Draftbit Coding Challenge is running at http://localhost:${port}/`
    );
  });
};

main();
