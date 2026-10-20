
import dotenv from "dotenv";
import app from "../app.js";

dotenv.config();

const PORT = Number(process.env.PORT || 5001);

app.listen(PORT, () => {
  console.log(`JobTrack API berjalan di port ${PORT}`);
});
