# Supabase Storage Setup for Product Images

## Required Setup Steps

### 1. Create Storage Bucket

1. Go to your Supabase Dashboard
2. Navigate to **Storage** in the left sidebar
3. Click **"New bucket"**
4. Set bucket name: `product-images`
5. Set it as **Public bucket** (so images can be displayed in the app)
6. Click **"Save"**

### 2. Set Bucket Policies (Optional but Recommended)

For better security, you can set up Row Level Security (RLS) policies:

```sql
-- Allow authenticated users to upload images
CREATE POLICY "Allow authenticated uploads" ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'product-images');

-- Allow public read access to images
CREATE POLICY "Allow public downloads" ON storage.objects
FOR SELECT TO public
USING (bucket_id = 'product-images');

-- Allow users to update their own uploads
CREATE POLICY "Allow authenticated updates" ON storage.objects
FOR UPDATE TO authenticated
USING (bucket_id = 'product-images');

-- Allow users to delete their own uploads
CREATE POLICY "Allow authenticated deletes" ON storage.objects
FOR DELETE TO authenticated
USING (bucket_id = 'product-images');
```

### 3. Update Products Table (if needed)

Make sure your products table has the `image_url` column:

```sql
-- Add image_url column if it doesn't exist
ALTER TABLE public.products 
ADD COLUMN IF NOT EXISTS image_url TEXT;
```

### 4. Test the Setup

1. Run the Flutter app
2. Navigate to a meal category
3. Tap the camera icon
4. Choose camera or gallery
5. Fill in product details
6. Save the product

The image should be uploaded to Supabase Storage and the product should appear in the list with the image displayed.

## Troubleshooting

### Common Issues:

1. **Permission Denied Error**: Make sure the storage bucket is set to public or has proper RLS policies
2. **Image Not Displaying**: Check if the image URL is valid and the bucket is accessible
3. **Upload Fails**: Verify internet connection and Supabase credentials
4. **Camera Permission Denied**: Make sure you've granted camera permissions to the app

### Debug Information:

The app logs detailed information about image upload process. Check the debug console for:
- `📤 Uploading product image...`
- `✅ Image uploaded successfully`
- `❌ Image upload failed`

## Image Management

- Images are automatically compressed to 80% quality and resized to max 1920x1080
- Unique filenames are generated using timestamps
- Failed uploads don't prevent product creation (product is saved without image)
- Images can be updated by editing the product (feature to be implemented)
