/*
 * Copyright 2021 Readium Foundation. All rights reserved.
 * Use of this source code is governed by the BSD-style license
 * available in the top-level LICENSE file of the project.
 */

package com.reactnativereadium.reader

import android.graphics.Color
import android.graphics.PointF
import android.graphics.RectF
import android.os.Bundle
import android.view.*
import android.view.accessibility.AccessibilityManager
import android.widget.LinearLayout
import android.widget.PopupWindow
import androidx.appcompat.app.AppCompatActivity
import androidx.appcompat.widget.SearchView
import androidx.fragment.app.commitNow
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.ViewModelProvider
import com.reactnativereadium.epub.UserSettings
import com.reactnativereadium.R
import com.reactnativereadium.utils.Highlight
import com.reactnativereadium.utils.toggleSystemUi
import java.net.URL
import kotlinx.coroutines.delay
import org.json.JSONObject
import org.readium.r2.navigator.DecorableNavigator
import org.readium.r2.navigator.Decoration
import org.readium.r2.navigator.epub.EpubNavigatorFragment
import org.readium.r2.navigator.util.BaseActionModeCallback
import org.readium.r2.navigator.ExperimentalDecorator
import org.readium.r2.navigator.Navigator
import org.readium.r2.navigator.SelectableNavigator
import org.readium.r2.shared.APPEARANCE_REF
import org.readium.r2.shared.publication.Locator
import org.readium.r2.shared.publication.Publication
import org.readium.r2.shared.ReadiumCSSName
import org.readium.r2.shared.SCROLL_REF

@OptIn(ExperimentalDecorator::class)
class EpubReaderFragment : VisualReaderFragment(), EpubNavigatorFragment.Listener {

    override lateinit var model: ReaderViewModel
    override lateinit var navigator: Navigator
    private lateinit var publication: Publication
    lateinit var navigatorFragment: EpubNavigatorFragment
    private lateinit var factory: ReaderViewModel.Factory
    private var initialSettingsMap: Map<String, Any>? = null

    private lateinit var menuScreenReader: MenuItem
    private lateinit var menuSearch: MenuItem
    lateinit var menuSearchView: SearchView

    private lateinit var userSettings: UserSettings
    private var isScreenReaderVisible = false
    private var isSearchViewIconified = true

    // Accessibility
    private var isExploreByTouchEnabled = false

    fun initFactory(
      publication: Publication,
      initialLocation: Locator?
    ) {
      factory = ReaderViewModel.Factory(
        publication,
        initialLocation
      )
    }

    fun updateSettingsFromMap(map: Map<String, Any>) {
      if (this::userSettings.isInitialized) {
        userSettings.updateSettingsFromMap(map)
        initialSettingsMap = null
      } else {
        initialSettingsMap = map
      }
    }

    fun updateHighlightsFromList(list: List<Highlight>) {
      val decorations = list.map { highlight ->
        var bundle = Bundle()
        bundle.putInt("id", highlight.id.toInt())

        Decoration(
          id = highlight.id.toString() + "-highlight",
          locator = highlight.locator,
          style = Decoration.Style.Highlight(tint = Color.YELLOW),
          extras = bundle
        )
      }

      lifecycleScope.launchWhenResumed {
        applyDecorations(decorations)
      }
    }

    private suspend fun applyDecorations(decorations: List<Decoration>) {
      (navigator as? DecorableNavigator)?.let { navigator ->
        navigator.applyDecorations(decorations, "highlights")
      }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        // FIXME: this should be checked
        // check(R2App.isServerStarted)

        if (savedInstanceState != null) {
            isScreenReaderVisible = savedInstanceState.getBoolean(IS_SCREEN_READER_VISIBLE_KEY)
            isSearchViewIconified = savedInstanceState.getBoolean(IS_SEARCH_VIEW_ICONIFIED)
        }

        ViewModelProvider(this, factory)
          .get(ReaderViewModel::class.java)
          .let {
            model = it
            publication = it.publication
          }

        val baseUrl = checkNotNull(requireArguments().getString(BASE_URL_ARG))

        childFragmentManager.fragmentFactory =
            EpubNavigatorFragment.createFactory(
                publication = publication,
                baseUrl = baseUrl,
                initialLocator = model.initialLocation,
                listener = this,
                config = EpubNavigatorFragment.Configuration().apply {
                    // Register the HTML template for our custom [DecorationStyleAnnotationMark].
                    // TODO: remove?
                    /* decorationTemplates[DecorationStyleAnnotationMark::class] = annotationMarkTemplate(activity) */
                    selectionActionModeCallback = customSelectionActionModeCallback
                }
            )

        setHasOptionsMenu(true)

        super.onCreate(savedInstanceState)
    }

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?): View? {
        val view = super.onCreateView(inflater, container, savedInstanceState)
        val navigatorFragmentTag = getString(R.string.epub_navigator_tag)

        if (savedInstanceState == null) {
            childFragmentManager.commitNow {
                add(R.id.fragment_reader_container, EpubNavigatorFragment::class.java, Bundle(), navigatorFragmentTag)
            }
        }
        navigator = childFragmentManager.findFragmentByTag(navigatorFragmentTag) as Navigator
        navigatorFragment = navigator as EpubNavigatorFragment

        return view
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        val activity = requireActivity()
        userSettings = UserSettings(
          navigatorFragment.preferences,
          activity,
          publication.userSettingsUIPreset
        )

       // This is a hack to draw the right background color on top and bottom blank spaces
        navigatorFragment.lifecycleScope.launchWhenStarted {
            val appearancePref = navigatorFragment.preferences.getInt(APPEARANCE_REF, 0)
            val backgroundsColors = mutableListOf("#ffffff", "#faf4e8", "#000000")
            navigatorFragment.resourcePager.setBackgroundColor(Color.parseColor(backgroundsColors[appearancePref]))
        }

        (navigator as? DecorableNavigator)?.let { navigator ->
            navigator.addDecorationListener("highlights", decorationListener)
        }
    }

    override fun onResume() {
        super.onResume()
        val activity = requireActivity()

        userSettings.resourcePager = navigatorFragment.resourcePager
        initialSettingsMap?.let { updateSettingsFromMap(it) }

        // If TalkBack or any touch exploration service is activated we force scroll mode (and
        // override user preferences)
        val am = activity.getSystemService(AppCompatActivity.ACCESSIBILITY_SERVICE) as AccessibilityManager
        isExploreByTouchEnabled = am.isTouchExplorationEnabled

        if (isExploreByTouchEnabled) {
            // Preset & preferences adapted
            publication.userSettingsUIPreset[ReadiumCSSName.ref(SCROLL_REF)] = true
            navigatorFragment.preferences.edit().putBoolean(SCROLL_REF, true).apply() //overriding user preferences
            userSettings.saveChanges()

            lifecycleScope.launchWhenResumed {
                delay(500)
                userSettings.updateViewCSS(SCROLL_REF)
            }
        } else {
            if (publication.cssStyle != "cjk-vertical") {
                publication.userSettingsUIPreset.remove(ReadiumCSSName.ref(SCROLL_REF))
            }
        }
    }

    override fun onDestroyView() {
        (navigator as? DecorableNavigator)?.removeDecorationListener(decorationListener)
        super.onDestroyView()
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        outState.putBoolean(IS_SCREEN_READER_VISIBLE_KEY, isScreenReaderVisible)
        outState.putBoolean(IS_SEARCH_VIEW_ICONIFIED, isSearchViewIconified)
    }

    override fun onTap(point: PointF): Boolean {
        requireActivity().toggleSystemUi()
        return true
    }

    companion object {

        private const val BASE_URL_ARG = "baseUrl"

        private const val SEARCH_FRAGMENT_TAG = "search"

        private const val IS_SCREEN_READER_VISIBLE_KEY = "isScreenReaderVisible"

        private const val IS_SEARCH_VIEW_ICONIFIED = "isSearchViewIconified"

        fun newInstance(baseUrl: URL): EpubReaderFragment {
            return EpubReaderFragment().apply {
                arguments = Bundle().apply {
                    putString(BASE_URL_ARG, baseUrl.toString())
                }
            }
        }
    }

    val customSelectionActionModeCallback: ActionMode.Callback by lazy { SelectionActionModeCallback() }

    private inner class SelectionActionModeCallback : BaseActionModeCallback() {
        override fun onCreateActionMode(mode: ActionMode, menu: Menu): Boolean {
            mode.menuInflater.inflate(R.menu.menu_action_mode, menu)
            menu.findItem(R.id.translate).isVisible = true
            return true
        }

        override fun onActionItemClicked(mode: ActionMode, item: MenuItem): Boolean {
            when (item.itemId) {
                R.id.translate -> sendTranslate()
                else -> return false
            }

            mode.finish()
            return true
        }
    }

    private fun sendTranslate() = viewLifecycleOwner.lifecycleScope.launchWhenResumed {
        (navigator as? SelectableNavigator)?.let { navigator ->
            navigator.currentSelection()?.locator?.let { locator ->
                channel.send(ReaderViewModel.Event.Translate(locator))
            }
            navigator.clearSelection()
        }
    }

    private fun sendShowHighlight(highlightId: Int) = viewLifecycleOwner.lifecycleScope.launchWhenResumed {
        channel.send(ReaderViewModel.Event.ShowHighlight(highlightId))
    }

    private fun sendDeleteHighlight(highlightId: Int) = viewLifecycleOwner.lifecycleScope.launchWhenResumed {
        channel.send(ReaderViewModel.Event.DeleteHighlight(highlightId))
    }

    // DecorableNavigator.Listener

    private val decorationListener by lazy { DecorationListener() }
    private var popupWindow: PopupWindow? = null

    private inner class DecorationListener : DecorableNavigator.Listener {
        override fun onDecorationActivated(event: DecorableNavigator.OnActivatedEvent): Boolean {
            val decoration = event.decoration
            val id = (decoration.extras?.get("id") as Int)
                .takeIf { it > 0 } ?: return false

            event.rect?.let { rect ->
                var eventRect = RectF(rect)
                view?.let { view ->
                    val locationOnScreen = IntArray(2)
                    view.getLocationOnScreen(locationOnScreen)
                    eventRect.offset(locationOnScreen[0].toFloat(), locationOnScreen[1].toFloat())
                }
                showHighlightPopup(
                    eventRect,
                    highlightId = id
                )
            }

            return true
        }
    }

    private fun showHighlightPopup(rect: RectF, highlightId: Int? = null) {
        viewLifecycleOwner.lifecycleScope.launchWhenResumed {
            if (popupWindow?.isShowing == true) {
                return@launchWhenResumed
            }

            val popupView = layoutInflater.inflate(
                R.layout.view_highlight_popup,
                null,
                false
            )

            popupView.measure(
                View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
                View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED)
            )

            popupWindow = PopupWindow(
                popupView,
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                isFocusable = true
                setOnDismissListener {
                    popupWindow = null
                }
            }

            popupWindow?.showAtLocation(popupView, Gravity.NO_GRAVITY, rect.left.toInt(), rect.bottom.toInt())

            popupView.run {
                findViewById<View>(R.id.show).setOnClickListener {
                    popupWindow?.dismiss()
                    highlightId?.let { id ->
                        sendShowHighlight(id)
                    }
                }
                findViewById<View>(R.id.delete).setOnClickListener {
                    popupWindow?.dismiss()
                    highlightId?.let { id ->
                        sendDeleteHighlight(id)
                    }
                }
            }
        }
    }
}
