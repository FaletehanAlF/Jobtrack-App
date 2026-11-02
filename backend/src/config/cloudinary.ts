import dotenv from "dotenv";
import { v2 as cloudinary } from "cloudinary";
dotenv.config();

export const CLOUDINARY_CV_FOLDER = "jobtrack/cvs";
export const CLOUDINARY_CV_RESOURCE_TYPE = "raw" as const;
export const CLOUDINARY_CV_DELIVERY_TYPE = "authenticated" as const;

interface CloudinaryConfig {
  cloudName: string;
  apiKey: string;
  apiSecret: string;
}

export function getCloudinaryConfig(): CloudinaryConfig | null {
  const cloudName = process.env.CLOUDINARY_CLOUD_NAME?.trim();
  const apiKey = process.env.CLOUDINARY_API_KEY?.trim();
  const apiSecret = process.env.CLOUDINARY_API_SECRET?.trim();

  if (!cloudName || !apiKey || !apiSecret) return null;

  return { cloudName, apiKey, apiSecret };
}

export function ensureCloudinaryConfigured(): boolean {
  const config = getCloudinaryConfig();

  if (!config) return false;

  cloudinary.config({
    cloud_name: config.cloudName,
    api_key: config.apiKey,
    api_secret: config.apiSecret,
    secure: true,
  });

  return true;
}

// Terapkan konfigurasi saat modul dimuat bila tersedia. Bila tidak tersedia,
// pemanggil (controller) akan menolak permintaan CV dengan respons aman.
ensureCloudinaryConfigured();

export const cloudinaryClient = cloudinary;
