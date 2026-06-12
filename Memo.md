# Travel Truth Layer Memo

## Approach and assumptions

I built a rules-first travel truth layer to link messy records from travel, card, expense, HR, flight, hotel, and OBT systems into employee-level trip clusters.

Since the data is noisy and sometimes conflicting, I prioritized precision over forcing every record into a trip. I used TMC bookings as the main trip anchors because they contain the strongest trip-level signals, including trip dates, record locators, traveler identity, and booking status. Other records were linked to these anchors using strong deterministic signals first, followed by weaker contextual signals.

The main linkage signals I used were employee ID, work email, record locator, booking ID, trip date overlap, city or itinerary context, merchant similarity, and text hints from notes or receipts. If there was not enough evidence, I assigned `UNKNOWN` for employee identity or `NO_TRIP` for unresolved or non-trip records.

## Top findings

The review queue contains {len(review_df)} ranked items. The highest-priority findings include inactive employee travel, possible duplicate expenses, hotel rate cap exceptions, refund or credit reconciliation, held or not-ticketed itineraries, and possible direct bookings outside the managed travel channel.

These findings may indicate financial leakage, policy violations, or reconciliation issues. For example, a card charge and expense line with the same merchant, date, and amount could be a valid corporate card reconciliation, but it could also indicate duplicate reimbursement. Travel-related card transactions with no matching TMC trip may also suggest out-of-channel bookings.

## Linkage uncertainty

Some records are intentionally ambiguous. Names may be abbreviated, emails may contain typos or be outdated, employee IDs may be missing, and guest travelers may not exist in HR.

Some OBT searches are true abandoned searches, while others may provide useful evidence for later direct bookings. Canceled, exchanged, held, or refunded travel records are not necessarily errors, but they require careful reconciliation.

The confidence scores in this project are heuristic only. They should be treated as practical confidence levels, not statistical probabilities.

## Production-grade next steps

With more time, I would extend this into a hybrid entity-resolution and trip-reconciliation pipeline.

The first layer would use deterministic joins based on record locator, booking ID, employee ID, and email. The second layer would use probabilistic matching on names, dates, routes, cities, merchants, and amounts. The final layer would generate a human review queue with reason codes and supporting evidence.

I would also add automated tests, data quality checks, rule versioning, and feedback loops from reviewer decisions. Over time, those reviewer decisions could be used to train a supervised matching model. For unstructured fields such as receipt text, comments, and card notes, I would use LLM-assisted extraction for booking references and exception reasons while keeping the final matching logic auditable.

## LLM usage

I used an LLM (ChatGPT with customized System Prompts) to help with project planning, code scaffolding, linkage logic design, review item ideas, and drafting the initial memo. All outputs were verified by running the notebook, inspecting linked records, and manually reviewing the final results.