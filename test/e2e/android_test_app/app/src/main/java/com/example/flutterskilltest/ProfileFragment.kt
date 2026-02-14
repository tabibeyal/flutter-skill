package com.example.flutterskilltest

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.TextView
import androidx.appcompat.app.AlertDialog
import androidx.fragment.app.Fragment
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.google.android.material.switchmaterial.SwitchMaterial

class ProfileFragment : Fragment() {

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?): View? {
        return inflater.inflate(R.layout.fragment_profile, container, false)
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        val settingsBtn = view.findViewById<Button>(R.id.settings_btn)
        val postsList = view.findViewById<RecyclerView>(R.id.user_posts_list)

        settingsBtn.setOnClickListener { showSettingsDialog() }

        val posts = (1..20).map { "My Post #$it" }
        postsList.layoutManager = LinearLayoutManager(requireContext())
        postsList.adapter = SearchFragment.SimpleTextAdapter(posts)
    }

    private fun showSettingsDialog() {
        val dialogView = LayoutInflater.from(requireContext()).inflate(R.layout.dialog_settings, null)
        val dialog = AlertDialog.Builder(requireContext())
            .setTitle("Settings")
            .setView(dialogView)
            .setPositiveButton("Close") { d, _ -> d.dismiss() }
            .create()
        dialog.show()
        // Set content description on the positive button for modal_close
        dialog.getButton(AlertDialog.BUTTON_POSITIVE)?.contentDescription = "modal_close"
    }
}
