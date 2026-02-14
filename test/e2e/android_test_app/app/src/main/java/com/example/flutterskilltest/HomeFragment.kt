package com.example.flutterskilltest

import android.content.Intent
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.*
import androidx.fragment.app.Fragment
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView

class HomeFragment : Fragment() {

    private var counter = 0

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?): View? {
        return inflater.inflate(R.layout.fragment_home, container, false)
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        val counterText = view.findViewById<TextView>(R.id.counter_text)
        val incrementBtn = view.findViewById<Button>(R.id.increment_btn)
        val decrementBtn = view.findViewById<Button>(R.id.decrement_btn)
        val editText = view.findViewById<EditText>(R.id.input_field)
        val submitBtn = view.findViewById<Button>(R.id.submit_btn)
        val resultText = view.findViewById<TextView>(R.id.result_text)
        val checkBox = view.findViewById<CheckBox>(R.id.test_checkbox)
        val detailBtn = view.findViewById<Button>(R.id.detail_btn)
        val feedList = view.findViewById<RecyclerView>(R.id.feed_list)

        counterText.text = "Count: $counter"

        incrementBtn.setOnClickListener {
            counter++
            counterText.text = "Count: $counter"
        }

        decrementBtn.setOnClickListener {
            counter--
            counterText.text = "Count: $counter"
        }

        submitBtn.setOnClickListener {
            resultText.text = "Submitted: ${editText.text}"
            Toast.makeText(requireContext(), "Submitted!", Toast.LENGTH_SHORT).show()
        }

        checkBox.setOnCheckedChangeListener { _, isChecked ->
            resultText.text = if (isChecked) "Checkbox: ON" else "Checkbox: OFF"
        }

        detailBtn.setOnClickListener {
            startActivity(Intent(requireContext(), DetailActivity::class.java).apply {
                putExtra("counter", counter)
            })
        }

        // Feed with 50+ items for scroll testing
        val feedItems = (0 until 50).map { i ->
            FeedItem("Post #$i", "This is the description for post $i. It contains interesting content.", (i * 7 + 3) % 100)
        }
        feedList.layoutManager = LinearLayoutManager(requireContext())
        feedList.adapter = FeedAdapter(feedItems) { item ->
            startActivity(Intent(requireContext(), DetailActivity::class.java).apply {
                putExtra("title", item.title)
                putExtra("description", item.description)
            })
        }
    }

    data class FeedItem(val title: String, val description: String, val commentCount: Int)

    class FeedAdapter(
        private val items: List<FeedItem>,
        private val onClick: (FeedItem) -> Unit
    ) : RecyclerView.Adapter<FeedAdapter.VH>() {

        class VH(view: View) : RecyclerView.ViewHolder(view) {
            val title: TextView = view.findViewById(R.id.card_title)
            val description: TextView = view.findViewById(R.id.card_description)
            val likeBtn: ImageButton = view.findViewById(R.id.like_btn)
            val commentCount: TextView = view.findViewById(R.id.comment_count)
        }

        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): VH {
            val view = LayoutInflater.from(parent.context)
                .inflate(R.layout.item_feed_card, parent, false)
            return VH(view)
        }

        override fun onBindViewHolder(holder: VH, position: Int) {
            val item = items[position]
            holder.title.text = item.title
            holder.description.text = item.description
            holder.commentCount.text = "${item.commentCount} comments"
            holder.itemView.contentDescription = "feed_item_$position"
            holder.likeBtn.contentDescription = "like_btn_$position"
            var liked = false
            holder.likeBtn.setOnClickListener {
                liked = !liked
                holder.likeBtn.setImageResource(
                    if (liked) android.R.drawable.btn_star_big_on else android.R.drawable.btn_star_big_off
                )
            }
            holder.itemView.setOnClickListener { onClick(item) }
        }

        override fun getItemCount() = items.size
    }
}
