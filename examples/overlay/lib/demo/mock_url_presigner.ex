defmodule Demo.MockUrlPresigner do
  @moduledoc """
  Mock URL presigner for demonstration purposes.

  In a real application, this would call a cloud storage service (like Google Cloud Storage or AWS S3)
  to generate presigned URLs for direct file uploads. This mock implementation generates
  fake URLs that simulate the real behavior for testing and demonstration.

  ## Real Implementation Example

  For a real Google Cloud Storage implementation, you might use:

      def sign(filename, context) do
        bucket = context.bucket
        prefix = context.prefix || ""
        object_name = "\#{prefix}\#{filename}"

        # Use your actual GCS presigner
        CoreData.Clients.UrlPresigner.sign(bucket, object_name)
      end
  """

  @doc """
  Generates a mock presigned URL for file upload.

  In a real implementation, this would:
  1. Generate a unique object name/path in cloud storage
  2. Create a presigned URL with expiration time
  3. Return the URL that the browser can use to upload directly

  ## Parameters

  - `filename` - The name of the file to upload
  - `context` - A map containing:
    - `:bucket` - The cloud storage bucket name
    - `:prefix` - The prefix/path for the object in storage
    - `:field_name` - The form field name (for additional context)

  ## Returns

  A mock presigned URL string. In a real implementation, this would be a valid
  presigned URL from your cloud storage provider.
  """
  def sign(filename, context) do
    bucket = context.bucket || "example-uploads"
    prefix = context.prefix || ""
    object_name = "#{prefix}#{filename}"

    # Generate a mock presigned URL
    # In production, this would be a real presigned URL from GCS, S3, etc.
    # For example: "https://storage.googleapis.com/bucket/path?signature=..."
    mock_url =
      "https://mock-storage.example.com/#{bucket}/#{URI.encode(object_name)}?mock_signature=#{generate_mock_signature()}"

    # Log the mock URL generation for debugging
    IO.puts("""
    [MockUrlPresigner] Generated mock presigned URL:
      Filename: #{filename}
      Bucket: #{bucket}
      Object Path: #{object_name}
      URL: #{mock_url}
    """)

    mock_url
  end

  # Generate a fake signature for the mock URL
  defp generate_mock_signature do
    :crypto.strong_rand_bytes(16)
    |> Base.url_encode64(padding: false)
    |> String.slice(0..31)
  end
end
