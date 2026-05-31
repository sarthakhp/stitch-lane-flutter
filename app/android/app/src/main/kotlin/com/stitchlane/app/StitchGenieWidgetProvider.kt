package com.stitchlane.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/// Home-screen widget with two buttons. Each launches MainActivity with a
/// `stitchgenie://` URI that the Flutter side (HomeWidgetService) routes to the
/// AI chat or the order creator, both with the mic auto-listening.
class StitchGenieWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.stitch_genie_widget).apply {
                val chatIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("stitchgenie://chat")
                )
                setOnClickPendingIntent(R.id.widget_chat_button, chatIntent)

                val orderIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("stitchgenie://order")
                )
                setOnClickPendingIntent(R.id.widget_order_button, orderIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
