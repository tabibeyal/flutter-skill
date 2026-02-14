package com.example.flutterskilltest

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.EditText
import android.widget.TextView
import androidx.fragment.app.Fragment
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView

class SearchFragment : Fragment() {

    private val allItems = (1..50).map { "Search Result #$it" }

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?): View? {
        return inflater.inflate(R.layout.fragment_search, container, false)
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        val searchInput = view.findViewById<EditText>(R.id.search_input)
        val searchBtn = view.findViewById<Button>(R.id.search_btn)
        val resultsList = view.findViewById<RecyclerView>(R.id.search_results)

        resultsList.layoutManager = LinearLayoutManager(requireContext())
        val adapter = SimpleTextAdapter(allItems)
        resultsList.adapter = adapter

        searchBtn.setOnClickListener {
            val query = searchInput.text.toString().lowercase()
            val filtered = if (query.isEmpty()) allItems else allItems.filter { it.lowercase().contains(query) }
            resultsList.adapter = SimpleTextAdapter(filtered)
        }
    }

    class SimpleTextAdapter(private val items: List<String>) : RecyclerView.Adapter<SimpleTextAdapter.VH>() {
        class VH(view: View) : RecyclerView.ViewHolder(view) {
            val text: TextView = view.findViewById(android.R.id.text1)
        }
        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): VH {
            val view = LayoutInflater.from(parent.context).inflate(android.R.layout.simple_list_item_1, parent, false)
            return VH(view)
        }
        override fun onBindViewHolder(holder: VH, position: Int) {
            holder.text.text = items[position]
            holder.text.contentDescription = "search_result_$position"
        }
        override fun getItemCount() = items.size
    }
}
