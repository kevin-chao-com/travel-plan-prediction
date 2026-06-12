# AI usage

## Tools/models used
I used ChatGPT with a custom System Prompt that I normally use for data science projects. It helps the model generate more structured plans, cleaner code, and more practical analysis. Below are the instructions I use.

* System Prompt — DataForge Lab (v2)

```
Role and Personality
You are DataForge Lab, a senior-level technical partner across data science, ML/AI, data engineering, software engineering, and general computing systems. Your role is to deliver production-quality solutions with clear reasoning, strong structure, and practical applicability. You are precise, pragmatic, and engineering-focused. You prioritize correctness, maintainability, and reproducibility over speed. Your tone is clear, structured, and professional with occasional light creativity.

Environment and Scope
In scope: data science and ML/AI workflows including data cleaning, feature engineering, modeling, evaluation, deployment, and MLOps; data engineering including ETL/ELT pipelines, dbt, Airflow, orchestration, and modern data warehouses; software engineering including Python, SQL, APIs, modular design, testing, and performance optimization; LLM systems including RAG pipelines, embeddings, fine-tuning, and agent workflows; general computing including hardware fundamentals, operating systems, cloud vs local environments, performance tuning, and troubleshooting.
Out of scope: unsafe hardware instructions, illegal or unethical activities, fabricated or unverifiable claims, and guessing private information.

Non-Negotiable Rules
Never fabricate facts or results. Never guess missing or private information and always state assumptions. Always produce runnable and logically correct code when required. Always follow formatting and tooling rules. Always stay within scope and safety constraints.

Tooling and Formatting Rules
Use Python, SQL, dbt, or Airflow when implementation is needed. Validate inputs and assumptions before coding. Use code blocks for code, tables for comparisons, and numbered steps for procedures.

User Preferences
Prefer structured outputs such as steps, tables, and code. Prefer concise answers for simple tasks and deeper analysis for complex tasks. Avoid em dashes and overly casual tone. Use precise and actionable language.

Behavior Scaling
Simple tasks require direct solutions. Medium tasks include explanation and best practices. Complex tasks require assumption validation, decomposition, structured solutions, and alternatives.

Input Evaluation
Check for ambiguity and missing details. Correct incorrect assumptions. Ask clarifying questions only when necessary. Pause if risk is high.

Guardrails
Refuse unsafe or illegal requests. Provide safe alternatives. Do not provide harmful or policy-violating instructions.

Dynamic Scaling
Adjust depth based on complexity and always optimize for clarity, usability, and correctness.

Formatting Templates
Step-by-step: define inputs, process data, apply logic, validate output.
Code: provide runnable implementation.
Comparison: option, pros, cons, best use case.
```

 

## What I asked the LLM to do
Below are the prompts I asked the LLM:

```
I have a data science project to complete. 
I have create a Github repo for organizing this project. 
Below I include all necessary information. 

First, I need you to help me understand more details on the data structure, 
the goal outputs, and provide a plan that I can code in Python and create 
a comprehensive reports within an hour.

(1) The story
Acme BioTech has a travel data problem.

Six systems disagree about what happened: - the TMC says a traveler booked a trip, - the OBT says someone searched, abandoned, or held an itinerary, - the card feed shows charges and credits, - the expense system shows what people claimed, - HR says who actually works here, - flight and hotel feeds add itinerary details.

Your job is to build the first useful version of a travel truth layer: link messy records to the right traveler and trip, then surface the highest-value issues a travel operations or finance team should review.

This is deliberately richer than anyone can fully solve in two hours. We are looking for how you structure ambiguity, use evidence, prioritize, and communicate.

(2) Data:
Treat this as a messy multi-source data linkage problem. The travel terms are defined below:

TMC: travel management company; the managed booking provider.
OBT: online booking tool; used for searching or booking travel.
Card transaction: corporate credit-card charge or credit.
Expense report: employee-submitted claim or reconciliation line.
Record locator: airline/TMC booking reference, usually a strong linkage clue.
Held / on hold: an itinerary was reserved but may not have been ticketed.
Ticketed: a flight was actually issued.
Exchange / credit / refund: a changed ticket can create canceled segments and negative card transactions.
Everything needed for policy interpretation is in data/travel_policy_rules.csv and data/hotel_rate_caps.csv.

Data dictionary
The data is synthetic. Names, companies, merchants, and amounts are fictional.

Common themes
Rows may disagree across systems. This is intentional.

Expected messiness includes: - abbreviated names (G Lee, M. Johnson); - preferred names (Dan, Liv, Sam); - old or typoed emails; - wrong or missing employee IDs; - canceled / exchanged flight rows; - refunds and negative card transactions; - non-travel card and expense records; - guest travelers with no HR record; - two different employees with similar names.

hr_employees.csv
Canonical employee roster.

Key columns: - employee_id: canonical ID to use in submissions. - legal_name, preferred_name, work_email: identity signals. - employment_status, end_date: use to identify inactive employees. - department, cost_center, manager_id, office_city, country: supporting context.

tmc_bookings.csv
Trip-level managed booking records from the travel management company.

Key columns: - booking_id: booking record ID. - record_locator: strong booking reference, often shared with flights/expenses. - traveler_name, traveler_email, traveler_employee_id: useful but not always correct. - trip_start_date, trip_end_date, origin_airport, destination_airport: itinerary signals. - booking_status: e.g. Ticketed, Exchanged, On hold - not ticketed. - source_channel: OBT or Agent. - total_booked_amount_usd: booked itinerary amount, not always equal to final card or expense total.

obt_searches.csv
Online booking tool search/session records.

Key columns: - action: Booked, Agent booked, Held, Abandoned, etc. - lowest_airfare_usd, selected_airfare_usd: useful for opportunity analysis. - policy_status: simplified policy status from the OBT. - booking_ref_hint: may contain a TMC record locator, but can be blank.

Important: abandoned searches may still be useful evidence for a later direct booking, but some are true no-trip decoys.

flight_segments.csv
Flight-level itinerary records.

Key columns: - booking_id, record_locator: linkage to TMC and expenses. - depart_airport, arrive_airport, depart_date, arrive_date: trip/date signals. - ticket_status: Ticketed, Canceled, Held. - ticket_number: blank if not ticketed. - fare_usd: segment fare or offer amount. Be careful with canceled/held rows.

hotel_stays.csv
Hotel reservation/stay records.

Key columns: - booking_id: may be blank for direct hotel data. - check_in, check_out, nights, nightly_rate_usd: compare to trip dates and policy caps. - hotel_name, hotel_city: useful for matching card and expense rows. - booking_status, source_channel: reservation context.

card_transactions.csv
Corporate credit card feed.

Key columns: - card_txn_id: card transaction ID. - employee_name_on_card, employee_email: cardholder identity. - transaction_date, post_date: date signals. - merchant_name, merchant_city, merchant_category: merchant matching and geography. - amount_usd: can be negative for credits/refunds. - card_notes: occasional hints.

Important: not every card row is travel. Do not force every row into a trip.

expense_reports.csv
Employee-submitted expense lines.

Key columns: - expense_line_id, report_id: expense identifiers. - submitter_name, submitter_email, employee_id_reported: submitter identity; may differ from traveler for guest travel. - transaction_date, merchant_name, city, amount_usd: matching signals. - receipt_text, claimed_booking_ref, comments: often contain useful unstructured clues. - reimbursement_status: Approved, Pending, etc.

travel_policy_rules.csv
Simplified policy rules for this exercise. These rules are intentionally business-readable, not exhaustive legal or compliance rules.

hotel_rate_caps.csv
City-level nightly hotel cap. Compare to hotel_stays.nightly_rate_usd; use judgment when notes indicate a possible exception.

airports.csv
Airport lookup table.

(3) Your mission
Create an analysis that answers:

Who traveled? Resolve records to canonical HR employees when possible.
Which records belong together? Group TMC bookings, OBT searches, flights, hotels, card transactions, and expense lines into trips.
What needs review? Rank the most important discrepancies, risks, or opportunities.
How would you productionize this? Explain the approach you would take with more time.
There are multiple good ways to do this. A rules-first approach, probabilistic matching, embeddings, LLM-assisted reasoning, or a hybrid approach can all do well if the reasoning is clear and reproducible.

(4) What to submit
Submit a folder or zip containing:

1. Code or notebook

Use your own editor and environment. Python, R, SQL, DuckDB, Polars, pandas, notebooks, scripts, or other tools are all fine.

2. linked_records.csv

A structured file with as many source records as you can confidently link.

Required columns:

column	description
source	One of: tmc_bookings, flight_segments, hotel_stays, obt_searches, card_transactions, expense_reports
record_id	The source system record ID, e.g. B1001, F1001, C2001, X3001
employee_id	Canonical HR employee ID, or UNKNOWN if no HR employee should be assigned
trip_id	Your own trip cluster ID. It does not need to match any hidden answer key. Use blank or NO_TRIP for decoys/non-trip records.
confidence	0.0 to 1.0
rationale	Short evidence note, e.g. record locator + amount + date, email + city + dates, guest traveler no HR row
It is better to submit fewer high-quality links than many forced low-confidence ones. That said, wide coverage helps if your precision is strong.

3. review_items.csv

A ranked list of issues, risks, or opportunities.

Required columns:

column	description
rank	1 is most important
category	Your issue type, e.g. duplicate_expense, missing_ticket, inactive_employee, policy_exception
severity	High, Medium, or Low
related_record_ids	Semicolon-separated IDs in source:record_id form, e.g. expense_reports:X3008;card_transactions:C2008
summary	What you found
recommended_action	What a travel ops / finance reviewer should do next
confidence	0.0 to 1.0
Good review items distinguish between “this is definitely wrong” and “this is suspicious but may have a legitimate explanation.”

4. memo.md

Keep it brief: about 500–900 words.

Suggested structure: - Approach and assumptions. - The top findings and why they matter. - Where the linkage is uncertain. - How you would make this production-grade. - How you used an LLM, if applicable.

5. AI_USAGE.md

LLMs are allowed and encouraged. We care about whether you use them effectively and responsibly.

Please disclose: - tools/models used, - what you asked them to do, - what you verified yourself, - any generated code or logic you materially relied on.
```


## What I verified myself
I verified that all generated Python code could run successfully in my local environment. This included checking package compatibility, file paths, dataframe schemas, and output formats. I also made sure the final outputs (`linked_records.csv` and `review_items.csv`) contained all required columns, correct data types, and reasonable values.

In addition, I manually inspected samples of the linked records and review items to confirm that the linkage logic, confidence scores, and detected issues made sense based on the underlying data.

-
### What I have done with the LLM after the initial outputs

Since I only had two hours to complete this project, I mainly used the LLM to speed up planning, code generation, debugging, and documentation.

After receiving the initial project plan and starter code, my first priority was to make sure the code could actually run on my local machine. I asked the LLM to break the code into separate cells so I could run everything step by step in a single Jupyter Lab notebook, which made debugging much easier.

I then went back and forth with the LLM to fix various runtime issues, including import errors, path mismatches, missing columns, schema assumptions, and logic bugs. This iterative debugging continued until the notebook ran successfully and produced the expected output files.

After that, I manually reviewed the outputs to ensure the records were linked reasonably and that the final CSV files matched the required submission format.

I also used the LLM to help draft the memo and other written content. However, I made sure I fully understood all generated explanations and only kept content that accurately reflected my implementation and conclusions.

 
## Generated code or logic I materially relied on

I relied on LLM-generated starter code and logic for several core parts of this project, mainly as an initial framework rather than the final solution.

This includes the overall pipeline for loading and preprocessing the datasets, helper functions for data cleaning and normalization, employee identity resolution, TMC-based trip clustering, record linkage across different data sources, confidence scoring, review item generation, and output file creation.

The LLM also helped me shape the rules-first matching strategy. The logic started with stronger signals such as employee ID, work email, booking ID, and record locator, then incorporated weaker signals like date overlap, city matching, merchant similarity, and text hints from notes or receipts.

That said, the initial code was not plug-and-play. I modified quite a bit during implementation to fix runtime issues, adjust to the actual dataset schema, and improve stability. The final notebook reflects both the LLM-generated scaffolding and my own debugging, validation, and refinement.



## Known limitations
This is a first-pass, rules-based solution built under a tight two-hour time limit, so it has several limitations.

The linkage logic mainly relies on deterministic rules and heuristic scoring, not a fully probabilistic model, so some ambiguous records may be missed or incorrectly linked.

I used TMC bookings as the main trip anchors, which works well for managed travel but is weaker for direct bookings that only show up in card or expense data.

The fuzzy matching for names and merchants is fairly simple, so it may struggle with severe typos, abbreviations, nicknames, or guest travelers without HR records.

Also, the confidence scores are heuristic only. They reflect practical confidence, not true statistical probabilities.

Finally, due to time constraints, I focused on the highest-value logic rather than full edge-case coverage, so complex cases like exchanges, partial refunds, or multi-city trips may still require manual review.


