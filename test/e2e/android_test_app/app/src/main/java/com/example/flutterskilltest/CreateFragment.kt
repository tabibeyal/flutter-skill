package com.example.flutterskilltest

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.*
import androidx.fragment.app.Fragment
import com.google.android.material.switchmaterial.SwitchMaterial

class CreateFragment : Fragment() {

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?): View? {
        return inflater.inflate(R.layout.fragment_create, container, false)
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        val spinner = view.findViewById<Spinner>(R.id.dropdown_select)
        val submitBtn = view.findViewById<Button>(R.id.create_submit_btn)

        val categories = arrayOf("General", "Tech", "Art", "Music", "Sports")
        spinner.adapter = ArrayAdapter(requireContext(), android.R.layout.simple_spinner_dropdown_item, categories)

        submitBtn.setOnClickListener {
            Toast.makeText(requireContext(), "Post published!", Toast.LENGTH_SHORT).show()
        }
    }
}
