package com.example.clickflix

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.ContentUris
import android.content.Context
import android.net.Uri
import androidx.tvprovider.media.tv.TvContractCompat
import androidx.tvprovider.media.tv.WatchNextProgram
import androidx.tvprovider.media.tv.PreviewProgram
import android.content.Intent
import android.util.Log

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.clickchannel.tv/recommendations"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "updateWatchNext" -> {
                    val movies = call.argument<List<Map<String, Any>>>("movies") ?: emptyList()
                    updateWatchNext(movies)
                    result.success(true)
                }
                "clearWatchNext" -> {
                    clearWatchNext()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun updateWatchNext(movies: List<Map<String, Any>>) {
        try {
            // Limpa o canal Watch Next existente para refrescar com a nova ordem/lista
            clearWatchNext()

            movies.forEach { movie ->
                val title = movie["title"] as? String ?: "Sem título"
                val description = movie["description"] as? String ?: ""
                val posterUrl = movie["posterUrl"] as? String ?: ""
                val contentId = movie["id"] as? String ?: ""
                val type = movie["type"] as? String ?: "movie"
                val playbackPosition = (movie["position"] as? Number)?.toInt() ?: 0
                val duration = (movie["duration"] as? Number)?.toInt() ?: 0

                val builder = WatchNextProgram.Builder()
                    .setType(if (type == "series") TvContractCompat.PreviewPrograms.TYPE_TV_EPISODE else TvContractCompat.PreviewPrograms.TYPE_MOVIE)
                    .setWatchNextType(TvContractCompat.WatchNextPrograms.WATCH_NEXT_TYPE_CONTINUE)
                    .setLastEngagementTimeUtcMillis(System.currentTimeMillis())
                    .setTitle(title)
                    .setDescription(description)
                    .setPosterArtUri(Uri.parse(posterUrl))
                    .setInternalProviderId(contentId)
                    .setLastPlaybackPositionMillis(playbackPosition * 1000)
                    .setDurationMillis(duration * 1000)

                // Intent para abrir o app no conteúdo específico
                val intent = Intent(context, MainActivity::class.java).apply {
                    action = Intent.ACTION_VIEW
                    data = Uri.parse("clickchannel://play/$contentId")
                }
                builder.setIntentUri(Uri.parse(intent.toUri(Intent.URI_INTENT_SCHEME)))

                contentResolver.insert(
                    TvContractCompat.WatchNextPrograms.CONTENT_URI,
                    builder.build().toContentValues()
                )
            }
        } catch (e: Exception) {
            Log.e("ClickChannel", "Erro ao atualizar Watch Next: ${e.message}")
        }
    }

    private fun clearWatchNext() {
        try {
            contentResolver.delete(
                TvContractCompat.WatchNextPrograms.CONTENT_URI,
                null,
                null
            )
        } catch (e: Exception) {
            Log.e("ClickChannel", "Erro ao limpar Watch Next: ${e.message}")
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        applyKeepScreenOn()
    }

    override fun onResume() {
        super.onResume()
        applyKeepScreenOn()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            applyKeepScreenOn()
        }
    }

    private fun applyKeepScreenOn() {
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }
}

