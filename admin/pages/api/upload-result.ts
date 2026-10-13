// Admin Next.js API example to upload a result PDF to Supabase Storage
// pages/api/upload-result.ts

import { NextApiRequest, NextApiResponse } from 'next';
import { createClient } from '@supabase/supabase-js';
import formidable from 'formidable';
import fs from 'fs';

export const config = { api: { bodyParser: false } };

const supabaseAdmin = createClient(process.env.SUPABASE_URL!, process.env.SUPABASE_SERVICE_ROLE!);

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  const form = formidable();
  form.parse(req, async (err, fields, files) => {
    if (err) return res.status(500).json({ error: err });
    const { appointment_id, uploaded_by, visible_to_user } = fields;
    const file = files?.file as formidable.File;
    if (!file) return res.status(400).json({ error: 'No file' });

    const buffer = fs.readFileSync(file.filepath);
    const filePath = `results/${appointment_id}/${Date.now()}-${file.originalFilename}`;

    const { data: uploadData, error: uploadError } = await supabaseAdmin.storage
      .from('results')
      .upload(filePath, buffer, { contentType: file.mimetype });

    if (uploadError) return res.status(500).json({ error: uploadError.message });

    const { data, error } = await supabaseAdmin
      .from('results')
      .insert({
        appointment_id,
        uploaded_by,
        file_path: uploadData.path,
        visible_to_user: visible_to_user === 'true',
        issued_at: new Date().toISOString(),
      })
      .select()
      .single();

    if (error) return res.status(500).json({ error: error.message });

    return res.status(200).json({ data });
  });
}
