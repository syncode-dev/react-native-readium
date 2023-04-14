package com.reactnativereadium.utils

import android.content.Context
import android.graphics.Bitmap
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.LifecycleCoroutineScope
import androidx.lifecycle.lifecycleScope
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.launch
import org.readium.r2.shared.publication.Publication
import org.readium.r2.shared.publication.asset.FileAsset
import org.readium.r2.shared.publication.services.cover
import org.readium.r2.streamer.Streamer
import java.io.File
import java.util.UUID

class CoverImageModule(reactContext: ReactApplicationContext) : ReactContextBaseJavaModule(reactContext) {
  override fun getName() = "CoverImageModule"
  private val context by lazy {
    reactContext.applicationContext
  }
  private val lifecycleScope: LifecycleCoroutineScope by lazy {
    (reactContext.currentActivity as AppCompatActivity).lifecycleScope
  }
  private val streamer: Streamer by lazy {
    Streamer(context)
  }

  private suspend fun importPublication(
    sourceFile: File
  ): Publication? {
    val publicationAsset = FileAsset(sourceFile)
    streamer.open(publicationAsset, allowUserInteraction = false)
      .onSuccess {
        return it
      }
      .onFailure { return null }

    return null
  }

  private suspend fun storeCoverImage(filePath: String, guideWidth: Int, guideHeight: Int): String? {
    val publicationDeferred = lifecycleScope.async {
      importPublication(File(filePath));
    }
    val publication = publicationDeferred.await() ?: return null

    val coverImageDeferred = lifecycleScope.async(Dispatchers.IO) {
      var coverImageUri: String? = null
      val bitmap: Bitmap? = publication.cover()
      bitmap?.let {
        val uuid = UUID.randomUUID().toString()
        val coverImageName = "cover$uuid.png"
        coverImageUri = "file://${context.filesDir}/$coverImageName"
        val fos = context.openFileOutput(coverImageName, Context.MODE_PRIVATE)

        if ((guideWidth > it.width && guideHeight > it.height)
          || (guideWidth <= 0 && guideHeight <= 0)) {
          it?.compress(Bitmap.CompressFormat.PNG, 80, fos)
        } else {
          val bitmapRatio = it.width.toFloat() / it.height
          var scaledWidth = if (guideWidth <= 0) it.width else guideWidth
          var scaledHeight = if (guideHeight <= 0) it.height else guideHeight
          if (scaledWidth.toFloat() / scaledHeight > bitmapRatio)
            scaledWidth = (scaledHeight * bitmapRatio).toInt()
          else
            scaledHeight = (scaledWidth / bitmapRatio).toInt()
          val resizedCover = Bitmap.createScaledBitmap(it, scaledWidth, scaledHeight, true)
          resizedCover?.compress(Bitmap.CompressFormat.PNG, 80, fos)
        }
        fos.flush()
        fos.close()
      }

      coverImageUri
    }

    return coverImageDeferred.await()
  }

  @ReactMethod
  fun getCoverImage(filePath: String, guideWidth: Int, guideHeight: Int, promise: Promise) {
    lifecycleScope.launch {
      val deferred = lifecycleScope.async {
        storeCoverImage(filePath, guideWidth, guideHeight);
      }
      val coverImageUri = deferred.await()
      if (coverImageUri != null)
        promise.resolve(coverImageUri)
      else
        promise.reject("Cover Image is null", "Can not get Cover Image");
    }
  }
}
