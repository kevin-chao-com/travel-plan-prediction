# Travel Truth Layer Memo

## Approach and assumptions

I built a rules-first travel truth layer that links messy travel, card, expense, HR, flight, hotel, and OBT records into employee-level trip clusters. The first version prioritizes precision over forced coverage. TMC bookings are treated as the primary trip anchors because they contain trip-level dates, record locators, traveler identity fields, and booking status. Other records are linked to those anchors using deterministic evidence first, then weaker contextual evidence.

The strongest linkage signals are employee ID, work email, record locator, booking ID, trip date overlap, city or itinerary context, merchant similarity, and unstructured text hints from notes or receipts. Records with insufficient evidence are assigned `UNKNOWN` for employee identity or `NO_TRIP` for non-trip or unresolved records.

## Top findings

The review queue contains {len(review_df)} ranked items. The highest-priority categories include inactive employee travel, possible duplicate expenses, hotel rate cap exceptions, refund or credit reconciliation, held or not-ticketed itineraries, and possible direct bookings outside the managed travel channel.

These findings matter because they represent potential financial leakage, compliance gaps, or operational reconciliation work. For example, a card charge and expense line with the same merchant, date, and amount may be legitimate corporate-card reconciliation, but it may also represent duplicate reimbursement risk. Similarly, travel-like card spend with no TMC trip may indicate leakage from the managed travel program.

## Linkage uncertainty

Several records are intentionally ambiguous. Names may be abbreviated, emails may be outdated or typoed, employee IDs may be missing or incorrect, and guest travelers may not exist in HR. Some OBT searches are abandoned decoys, while some may be useful evidence for later direct bookings. Canceled, exchanged, held, or refunded travel records are not automatically errors, but they should be reconciled carefully.

The current scoring model is transparent and reproducible, but it is not a calibrated probabilistic model. Confidence values should therefore be interpreted as operational confidence, not statistical probability.

## Production-grade next steps

With more time, I would productionize this as a hybrid entity-resolution and trip-reconciliation pipeline. The first layer would use deterministic joins on record locator, booking ID, employee ID, and email. The second layer would use probabilistic matching over names, dates, route, city, merchant, and amount. The third layer would create a human-review queue with reason codes and supporting evidence.

I would also add automated tests, data quality checks, versioned rules, lineage tracking, and reviewer feedback loops. Over time, reviewer decisions could train a supervised matching model. For unstructured fields such as receipt text, comments, and card notes, I would use controlled LLM-assisted extraction for booking references, exception explanations, and merchant normalization, while keeping final matching rules auditable.

## LLM usage

An LLM (ChatGPT, customized System Prompts) was used to help structure the project plan, design the linkage logic, identify review categories, and draft starter code. All logic should be verified by running the notebook, inspecting linked records, and manually reviewing high-severity findings before submission.