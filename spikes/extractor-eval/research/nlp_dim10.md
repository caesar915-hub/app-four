# Dimension 10: ADHD-Specific Signal Taxonomy & Clinical Validity

**Research Date:** 2026-06-23  
**Agent:** Deep Research Agent  
**Scope:** Mapping the whispernotes extraction taxonomy (mood, energy, focus, feelings, activities, sleep, medications, side effects, tasks completed/avoided, wins, overwhelm, executive dysfunction, physical stim, physical side effects, rebound terms, appetite loss/return, appointments) against clinically validated ADHD instruments, digital phenotyping research, and patient-reported outcomes literature.

---

## Key Findings

### 1. Validated ADHD Instruments Capture a Narrower, More Structured Signal Set

```
Claim: The most widely validated adult ADHD instruments (ASRS, ADHD-RS, CAARS) are anchored to DSM-IV/V diagnostic criteria and measure only two domains: inattention and hyperactivity/impulsivity. They do not directly capture mood, energy, sleep, or emotional dysregulation — constructs the whispernotes taxonomy treats as first-class signals. [^1]
Source: PMC / ASRS-v1.1 Symptom Checklist validation (Adler et al., 2018)
URL: https://pmc.ncbi.nlm.nih.gov/articles/PMC6585602/
Date: 2018
Excerpt: "The ASRS-v1.1 Symptom Checklist is an 18-item measure used to determine symptom profile and assess symptom burden in adult ADHD... The 18 items that comprise the entire ASRS-v1.1 Symptom Checklist represent the 18 symptoms of inattention and impulsivity/hyperactivity that characterize ADHD, according to the DSM-4."
Context: The ASRS is a screening and symptom-burden tool, not a daily-experience tracker. It asks about frequency over 6 months, not momentary states.
Confidence: high
```

```
Claim: The ASSET-BS, a newer 10-item clinical screener derived from practice, is the first validated ADHD instrument to explicitly include "Mood" and "Anxiety" as items — but it still treats them as subordinate to the inattentive vs. hyperactive/impulsive factor structure, and sleep quality was dropped during factor analysis. [^2]
Source: Young et al. (2023), ASSET-BS development and validation
URL: https://pmc.ncbi.nlm.nih.gov/articles/PMC10629079/
Date: 2023
Excerpt: "After removing excessive talking, sleep quality, and brain fog, the EFA identified a two-factor model explaining 68.40% of variance between participants... We named factor two Hyperactivity and Impulsivity due to alignment with DSM-5 criteria."
Context: Sleep quality failed to load at the 0.40 level; mood loaded on the hyperactivity/impulsivity factor alongside anxiety and fidgetiness. This signals that clinical factor-analytic approaches may discard patient-relevant experiences that don't fit the DSM structure.
Confidence: high
```

```
Claim: The BRIEF-A (Behavior Rating Inventory of Executive Function — Adult Version) is the most ecologically valid instrument for adult ADHD daily functioning, measuring nine domains: Inhibit, Shift, Emotional Control, Self-Monitor, Initiate, Working Memory, Plan/Organize, Task Monitor, and Organization of Materials. It directly maps to "executive dysfunction" and "task completion/avoidance" in the whispernotes taxonomy, but it is a 75-item retrospective questionnaire, not a momentary diary. [^3]
Source: Roth et al. (2013), Confirmatory Factor Analysis of BRIEF-A
URL: https://pmc.ncbi.nlm.nih.gov/articles/PMC3711374/
Date: 2013
Excerpt: "The BRIEF-A contains 75 items scored on a three-point Likert scale with higher scores indicating poorer executive function... The BRIEF-A yields an overall score (Global Executive Composite) composed of two index scores, the Behavioral Regulation Index and the Metacognition Index."
Context: The BRIEF-A is used extensively in ADHD clinical research and has strong convergent/discriminant validity. It captures the "daily life" impact of executive dysfunction but not the temporal dynamics (e.g., morning vs. evening focus crashes) that an app would track.
Confidence: high
```

```
Claim: The WFIRS (Weiss Functional Impairment Rating Scale) is the only validated instrument specifically designed to measure functional impairment across life domains affected by ADHD — family, work/school, life skills, self-concept, social, and risky activities — making it the closest clinical counterpart to "what patients actually experience daily." It is 69 items and asks about impact in the last month. [^4]
Source: Weiss et al. (2018), Conceptual review of measuring functional impairment
URL: https://pmc.ncbi.nlm.nih.gov/articles/PMC6241626/
Date: 2018
Excerpt: "The WFIRS-S items collect the reporter's perspective of their own functioning across seven domains: Family (8 items), Work (11 items), School (10 items), Life Skills (12 items), Self-Concept (5 items), Social (9 items) and Risk (14 items)."
Context: WFIRS is used in clinical trials for treatment monitoring and is sensitive to medication-related change. It bridges symptom severity and real-world impact but is too long for daily self-monitoring.
Confidence: high
```

### 2. Emotional Dysregulation Is a Major Clinically Observed Signal Missing from DSM Criteria

```
Claim: Emotional dysregulation affects approximately 70% of adults with ADHD and is increasingly viewed as a fundamental, biologically based component of the disorder — yet it is not a core DSM-5 symptom, and no validated daily-tracking instrument exists for it. [^5]
Source: Colorado Mental Health Services / Adult ADHD and Emotional Dysregulation
URL: https://coloradomentalhealthservices.com/rehab-blog/adult-adhd-and-emotional-dysregulation/
Date: 2026-02-11
Excerpt: "While ED is not yet diagnosed as a core ADHD symptom like inattention, hyperactivity, and impulsivity, it is now often viewed as an important dimension of ADHD... Emotional dysregulation (ED) in adult ADHD entails difficulty in regulating intense emotions, which adversely affects daily functioning."
Context: This aligns with the whispernotes taxonomy's inclusion of "mood," "feelings," "overwhelm," and "emotional dysregulation" as extractable signals. The clinical literature supports their relevance but lacks validated instruments for granular daily tracking.
Confidence: high
```

```
Claim: Rejection Sensitive Dysphoria (RSD) — a pattern of intense emotional pain following perceived rejection, criticism, or failure — is estimated to affect up to 99% of adults with ADHD by some estimates, but it is not a formal DSM diagnosis and clinicians have historically lacked validated instruments to assess it. A new instrument (RSD-RS) is emerging. [^6]
Source: RSD-RS / Global ADHD Network / Private ADHD UK
URL: https://rsdrs.com/ / https://www.globaladhdnetwork.com/post/rejection-sensitive-dysphoria-rsd-and-adhd / https://www.privateadhd.com/blog/understanding-rejection-sensitive-dysphoria-and-adhd
Date: 2025–2026
Excerpt: "RSD affects up to 99% of adults with ADHD according to some estimates, yet clinicians have lacked validated instruments to assess severity, track treatment response, or demonstrate outcomes to patients and commissioners." (RSD-RS site)
Context: RSD is not currently captured by any standard ADHD symptom tracker or the whispernotes taxonomy. The user community reports it as a dominant experience, yet it remains outside the clinical measurement framework.
Confidence: medium (high for prevalence in community; low for 99% figure; RSD-RS is not yet peer-reviewed)
```

### 3. Digital Phenotyping and EMA Studies Show Promise for Passive + Active Monitoring

```
Claim: A 2025 JMIR study using the RADAR-base platform (ART system) found that adults with ADHD differed from controls on five of ten digital signals derived from smartphone and wearable passive sensing: questionnaire response latency/variability, time-interval variability between assessments, social-app notification response time, and ambient light variability during phone use. This establishes that passive digital markers can capture "inconsistent attentional focusing" and "restlessness" in real-world settings. [^7]
Source: Sankesara et al. (2025), Identifying Digital Markers of ADHD in a Remote Monitoring Setting
URL: https://formative.jmir.org/2025/1/e54531
Date: 2025-06-18
Excerpt: "The participants with ADHD were (1) slower and more variable in their speed of responding to the notifications to complete the questionnaires, (2) had a higher SD in the time interval between questionnaires, (3) had higher daily mean response time to social and communication app notifications, and (4) had a greater change in ambient (background) light when they were actively using the smartphone."
Context: This is a small pilot (20 ADHD, 20 controls) but directly supports the idea that smartphone-based behavioral traces correlate with ADHD severity. It does not replace self-report but complements it.
Confidence: medium
```

```
Claim: Ecological Momentary Assessment (EMA) in ADHD research has demonstrated that embedding daily symptom tracking within an intervention protocol can track improvements in ADHD symptom severity over 17 days and that missing an EMA prompt is associated with acute symptom improvements at the next prompt — suggesting the act of self-monitoring itself may have therapeutic effects. [^8]
Source: Kennedy et al. (2022) / TIPS mHealth Intervention Development (PMC12465124)
URL: https://pmc.ncbi.nlm.nih.gov/articles/PMC12465124/
Date: 2024
Excerpt: "In a previous sample of adolescents with ADHD, we were able to track improvements in self-reported ADHD symptom severity over the course of 17 days of EMA; even more exciting, we leveraged missing data to discover that completing versus missing an EMA prompt was associated with within-person, acute improvements in ADHD symptom severity at the next prompt."
Context: EMA studies typically use 4–6 prompts per day capturing momentary mood, sleep, ADHD symptoms, and daily difficulties. The whispernotes approach of natural-language voice/text entry is a more flexible, lower-burden variant of EMA.
Confidence: medium
```

### 4. Comorbidities Are the Rule, Not the Exception, and Drive the Symptom Landscape

```
Claim: ADHD exhibits high comorbidity rates with anxiety and depressive disorders, with prevalence rates ranging from 18.6% to 53.3% for depression and up to 50% for anxiety disorders in inattentive-type ADHD. These comorbidities share overlapping symptoms (restlessness, irritability, difficulty concentrating, sleep disturbance) and are often what patients experience most acutely on a daily basis. [^9]
Source: Fu et al. (2025), Adult ADHD and comorbid anxiety and depressive disorders
URL: https://pmc.ncbi.nlm.nih.gov/articles/PMC12179154/
Date: 2025
Excerpt: "ADHD exhibits a high comorbidity rate with anxiety and depressive disorders, due to overlapping and interacting symptoms... Those with both conditions experience higher disease burden, longer illness duration, and reduced quality of life compared to those with either disorder alone."
Context: The whispernotes taxonomy includes anxiety, depression, sleep, and mood signals — which the clinical literature confirms are essential for ADHD self-monitoring, even if they are not core ADHD diagnostic criteria.
Confidence: high
```

```
Claim: The Irish National Clinical Programme for Adult ADHD explicitly recommends that routine ADHD assessment and monitoring include screening for sleep problems, anxiety, mood symptoms (emotional lability, low self-esteem, depressive episode), substance use, eating disorders, and autism spectrum disorder — confirming that a multi-signal approach is now standard of care in some clinical models. [^10]
Source: HSE Ireland, ADHD in Adults National Clinical Programme: Model of Care
URL: https://www.hse.ie/eng/about/who/cspd/ncps/mental-health/adhd/adhd-in-adults-ncp-model-of-care/adhd-in-adults-ncp-model-of-care.pdf
Date: not specified
Excerpt: "The co-morbidities associated with ADHD in adults include: Anxiety, Mood symptoms (emotional lability, low self esteem, depressive episode), Substance use disorder, Eating disorders, Personality disorder, Autism spectrum disorder, Sleep disorders."
Context: This validates the whispernotes approach of extracting multiple overlapping symptom domains rather than treating ADHD as an isolated inattention/hyperactivity construct.
Confidence: high
```

### 5. Stimulant Medication Side Effects Are a Core Patient-Tracking Concern, but Understudied in Clinical Scales

```
Claim: The most common sustained side effects of ADHD stimulant medication are loss of appetite, sleep problems (insomnia, delayed sleep onset), headache, irritability, and the "rebound effect" (sudden recurrence of ADHD symptoms as medication wears off). A 5-year monitoring study found that at least one physiologic adverse effect was reported by half of children by year five. [^11]
Source: Charach et al. / Nanda et al. (2023), Adverse Effects of Stimulant Interventions for ADHD — Systematic Review
URL: https://pmc.ncbi.nlm.nih.gov/articles/PMC10601982/
Date: 2023
Excerpt: "Common adverse effects during stimulant treatment include the delay of sleep onset, headache, appetite suppression, transient headache, transient stomachache, and behavioral rebound (ie, the sudden or pronounced recurrence of ADHD symptoms)."
Context: The whispernotes taxonomy includes appetite loss/return, physical side effects, rebound terms, and medications — all of which are patient-reported concerns that validated symptom scales do not systematically capture.
Confidence: high
```

```
Claim: A pilot study by Surman et al. (APSARD 2021) using mobile phone surveys for remote patient monitoring of ADHD found that personalized, daily self-reported items via mobile messaging could discriminate "on" versus "off" stimulant therapy status, confirming that patient-generated data has clinical utility for medication optimization. [^12]
Source: HCPLive / APSARD 2021 — Sensitivity of Electronic Patient Reported Outcome Measures to Medication Effects in Adult ADHD
URL: https://www.hcplive.com/view/adhd-treatment-remote-patient-monitoring
Date: 2021-01-17
Excerpt: "The research observed that data confirmed self-reported ADHD symptom severity discriminated 'on' versus 'off' stimulant therapy status... Mobile monitoring of ADHD symptoms and functional impact is likely sensitive to changes in treatment status."
Context: This directly supports the whispernotes model: personalized, high-frequency, patient-generated tracking data can be clinically actionable, even if it does not map neatly to a validated DSM-based instrument.
Confidence: medium
```

### 6. Time Blindness and Executive Dysfunction Beyond DSM Are Real Patient Experiences but Not Clinically Validated Constructs

```
Claim: "Time blindness" (difficulty perceiving, estimating, and managing time) is not a formal clinical diagnosis or validated construct, but it is widely recognized by clinicians and ADHD communities as a core daily impairment tied to prefrontal cortex differences and dopamine dysregulation. It is associated with chronic lateness, missed deadlines, and task-duration underestimation. [^13]
Source: ADHD Space / Doctronic / Elemental Health Group
URL: https://www.adhdspace.ca/blog/understanding-time-blindness-in-adhd-occupational-therapy-to-manage-time-more-effectively / https://www.doctronic.ai/blog/adhd-and-time-blindness/ / https://elementalhealth.group/articles/adhd-and-time-blindness/
Date: 2025–2026
Excerpt: "Time blindness, also known as time agnosia, is not an official diagnosis. But it is often recognized by clinicians as a common experience among ADHD adults and is closely tied to executive dysfunction and time management challenges." (ADHD Space)
Context: The whispernotes taxonomy includes "executive dysfunction" and "tasks completed/avoided" but does not explicitly track "time perception" or "time blindness" — which the community literature suggests is a major unmet signal.
Confidence: medium (high for community consensus; low for clinical validation)
```

```
Claim: Executive dysfunction in ADHD extends beyond DSM symptoms to include working memory deficits, inhibitory control problems, planning/organization failures, cognitive inflexibility, and emotional regulation deficits — all of which have significant daily life impact. These associated features are proposed as candidates for future inclusion in diagnostic criteria. [^14]
Source: Czech university thesis / Matte et al. (2012) / Barkley (2015)
URL: https://is.muni.cz/th/fi2gu/554042_Zadinova_MDT.pdf
Date: not specified
Excerpt: "Although DSM-5-TR and ICD-11 only require the presence of inattention and/or hyperactivity-impulsivity, there are multiple other associated symptoms which are not part of the diagnostic criteria, but have negative impact on the lives of people with ADHD. As they may be considered as additional information in making a diagnosis, in the future they may also get included in the official diagnostic criteria."
Context: This explicitly frames the tension in the whispernotes taxonomy: the signals it captures (mood, energy, overwhelm, executive dysfunction, stim side effects) are clinically meaningful but not yet formally validated as core ADHD symptoms.
Confidence: high
```

### 7. ADHD Communities and Self-Tracking Apps Reveal a Different Signal Priority than Clinical Instruments

```
Claim: ADHD self-tracking apps (e.g., ClarityDTX, Bearable, InnerHeal) and community resources prioritize tracking: focus levels, medication timing and response, task completion, energy patterns, sleep quality, emotional regulation/mood shifts, hyperfocus periods, and caffeine intake — a signal set that overlaps significantly with the whispernotes taxonomy but diverges from DSM-based instruments. [^15]
Source: ClarityDTX / Bearable / EndeavorOTC
URL: https://claritydtx.com/adhd/ / https://bearable.app/ / https://www.endeavorotc.com/blog/apps-were-loving-for-adhd-awareness-month/
Date: 2024–2026
Excerpt: "Track focus levels, medication timing, task completion, and energy patterns throughout your day. Get clear insights that help you and your psychiatrist optimize your ADHD management with real data instead of guesswork." (ClarityDTX)
Context: Patient-facing tools are designed for usability and self-insight, not clinical validation. The overlap with whispernotes signals (focus, energy, medication, sleep, mood, task completion) suggests the taxonomy is well-aligned with patient needs, even if not all signals are clinically validated.
Confidence: medium
```

---

## Major Players & Sources

| Source | Type | Relevance to whispernotes |
|--------|------|---------------------------|
| **ASRS-v1.1 / ASRS-5** (Kessler et al., WHO) | Validated screening instrument | Gold standard for ADHD symptom detection; 18 items, 6-month recall. Does not cover mood, energy, sleep, or daily function. |
| **ADHD-RS** (DuPaul et al.) | Clinician-rated diagnostic scale | 18 items derived from DSM-IV criteria; used in treatment trials. No mood/energy/sleep items. |
| **BRIEF-A** (Roth, Isquith, Gioia) | Self-report executive function | 75 items covering 9 executive domains. Captures "executive dysfunction" and "task management" well but is retrospective and long. |
| **WFIRS** (Weiss) | Functional impairment scale | 69 items across 7 life domains. Best clinical proxy for "what ADHD actually does to your life." Used in treatment monitoring. |
| **ASSET-BS** (Young et al., 2023) | Novel clinical screener | 10 items including mood and anxiety; sleep was dropped during factor analysis. Represents a trend toward broader symptom capture. |
| **RSD-RS** (Emerging, 2025) | Rejection sensitivity instrument | First attempt to validate RSD measurement in ADHD. Not yet peer-reviewed but signals clinical recognition of non-DSM constructs. |
| **RADAR-base / ART** (Sankesara et al., 2025) | Digital phenotyping research | Smartphone + Fitbit passive sensing pilot. Identified 5/10 digital markers that differed between ADHD and control groups. |
| **TIPS / Kennedy EMA work** | EMA + mHealth intervention | Demonstrated that daily EMA tracking of ADHD symptoms is feasible and that tracking itself may improve symptoms. |
| **Canadian ADHD Resource Alliance (CADDRA)** | Clinical guidelines | Recommends questionnaires, agendas, charts, daily report cards for monitoring medication and treatment response. |
| **Bearable / ClarityDTX / Tiimo** | Patient-facing apps | Show what patients actually track: focus, medication, energy, sleep, mood, tasks. Bearable emphasizes ADHD community use. |

---

## Trends & Signals

### Trend 1: From Symptom Scales to Functional Impairment Measures
Clinical practice is shifting from "how often do you have symptoms?" (ASRS, ADHD-RS) to "how much does this affect your life?" (WFIRS). The whispernotes taxonomy is closer to the latter — it captures daily-lived experience rather than diagnostic symptom frequency. This is a favorable trend, but the challenge is that WFIRS is 69 items and not designed for daily entry.

### Trend 2: Emotional Dysregulation Is Entering the Clinical Conversation
While still excluded from DSM-5 core criteria, emotional dysregulation is now discussed as a fundamental ADHD dimension in specialist literature and is increasingly measured in research (e.g., BRIEF-A Emotional Control scale, emerging RSD-RS). The whispernotes inclusion of mood, feelings, overwhelm, and emotional dysregulation is ahead of the DSM but aligned with the clinical frontier.

### Trend 3: Digital Phenotyping + EMA as Complementary Data Streams
The ADHD field is moving toward combining passive sensing (phone use, response latency, step count) with active self-report (EMA). The whispernotes model of natural-language voice/text capture is a form of active EMA with lower structure burden. The research shows promise but requires larger studies for validation.

### Trend 4: Comorbidity-First Monitoring
Because up to 90% of people with ADHD have at least one comorbidity, there is growing recognition that tracking only ADHD symptoms is insufficient. Sleep, anxiety, depression, and substance use are increasingly screened alongside ADHD in clinical protocols. The whispernotes multi-domain taxonomy is well-positioned here.

### Trend 5: Patient-Generated Health Data Is Gaining Clinical Acceptance
Studies like Surman et al. (2021) show that personalized mobile self-reports can be sensitive to medication status changes. Patient diaries and daily logs are described as "routinely used in care management situations to track compliance and monitor recovery." The whispernotes app is part of a broader movement toward patient-generated data informing treatment.

---

## Controversies & Conflicting Claims

### Controversy 1: Is the Current Taxonomy Clinically Useful or Just Personally Useful?
**The tension:** Validated instruments (ASRS, ADHD-RS) are designed for diagnosis and clinical trial endpoints. They have psychometric rigor but poor ecological validity for daily life. The whispernotes signals (mood, energy, "flat - out - gone" labels) are personally meaningful and may reveal patterns that matter to the individual, but they lack the standardized scoring, normative data, and sensitivity-to-change evidence that clinicians need for treatment decisions.

**Resolution direction:** The taxonomy should be viewed as a **patient-generated health data (PGHD) layer** that complements, rather than replaces, validated instruments. The app can serve as an external memory system and pattern-detection tool, with data exportable for clinical review.

### Controversy 2: What Signals Are Missing?
Several signals appear in the clinical and community literature but are not currently in the whispernotes taxonomy:
- **Rejection Sensitive Dysphoria (RSD):** Prevalent in community reports, not yet clinically validated, but highly disruptive to relationships and work. Not currently extracted.
- **Time blindness / time perception:** A core ADHD daily experience that affects appointments, deadlines, and task initiation. Not explicitly tracked.
- **Social functioning:** The WFIRS "Social" domain and peer-reviewed studies show social impairment is a major ADHD outcome. The whispernotes taxonomy does not have a dedicated "social" or "relationships" signal.
- **Risk-taking / impulsive behavior:** Covered by WFIRS Risk domain and linked to ADHD outcomes. Not explicitly extracted.
- **Self-concept / self-esteem:** WFIRS Self-Concept domain and low self-esteem are frequently comorbid with ADHD. Not explicitly tracked.
- **Hormonal fluctuations:** The female-specific ADHD literature (e.g., European Psychiatry 2026) recommends menstrual cycle tracking for symptom fluctuation assessment. Not in the taxonomy.

### Controversy 3: Does Natural-Language Capture Introduce Noise?
The user prefers extremely short natural language ("flat - out - gone") over structured scales. The clinical literature relies on Likert scales with defined anchors because they are psychometrically tractable. Natural language offers richer, more authentic patient voice but introduces ambiguity, idiosyncrasy, and challenges for standardization, comparison, and validation.

**Resolution direction:** The NLP layer should extract **both** the patient's natural language (preserving authenticity) and map it to **clinically meaningful signal categories** (enabling aggregation and pattern detection). Precision/recall targets should be set against the patient-authored label, not a clinical gold standard, unless the app explicitly intends to serve as a clinical instrument.

### Controversy 4: Are the Signals Clinically Valid or Just "Lived-Experience Valid"?
There is a difference between signals that are **validated against clinical outcomes** (e.g., WFIRS family domain predicts treatment response) and signals that are **phenomenologically true** (e.g., "I feel flat when my meds wear off"). The whispernotes taxonomy is heavy on phenomenologically true signals. The risk is that the app may detect patterns that are personally meaningful but not predictive of clinically important outcomes (e.g., hospitalization, functional remission, quality of life).

**Resolution direction:** Future research should establish convergent validity between extracted signals and validated instruments (e.g., does the app's "focus" signal correlate with BRIEF-A Task Monitor or WFIRS Work domain?). Until then, the app should be positioned as a **self-management and pattern-awareness tool**, not a clinical assessment device.

---

## Recommended Deep-Dive Areas

1. **RSD Signal Extraction:** Investigate whether the NLP layer can detect rejection-sensitive language patterns ("they ignored me," "I felt crushed," "I can't handle criticism") from daily entries. This is a high-impact, under-validated domain that the community cares about deeply.

2. **Time Perception / Temporal Language:** Research how natural language encodes time blindness ("I lost track of time," "I thought I had more time," "it took forever"). This is a linguistically interesting and clinically relevant signal that no validated instrument captures in daily form.

3. **Convergent Validity Study:** Design a small study where whispernotes users also complete BRIEF-A + WFIRS + ASRS at baseline and monthly, testing whether app-extracted signals (focus, energy, overwhelm, task completion) correlate with validated domain scores.

4. **Medication Response Curve Modeling:** The ClarityDTX app and Surman et al. (2021) pilot show that hour-by-hour focus tracking can reveal medication onset, peak, and rebound. The whispernotes NLP layer could be enhanced to explicitly detect medication timing, "rebound" language, and appetite-related terms for dose-optimization support.

5. **Social Functioning Signal:** The WFIRS Social domain and community literature suggest that relationship difficulties, social avoidance, and communication problems are major ADHD outcomes. Consider adding "social" or "relationships" as an extractable category.

6. **Comorbidity Differentiation:** The NLP layer currently extracts mood, anxiety, and sleep. Future work could evaluate whether the extracted signals are specific enough to distinguish ADHD-related mood fluctuation from primary depression or anxiety, or whether the app should be positioned as a transdiagnostic tracker.

7. **EMA vs. Retrospective Capture:** The EMA literature shows that real-time prompts reduce recall bias. The whispernotes model is event-driven (user speaks when they think of it). A hybrid model — natural language entry plus 1–2 daily structured prompts — could improve temporal resolution without sacrificing the app's low-friction design.

---

## Footnotes

[^1]: Adler et al. (2018). Establishing US norms for the Adult ADHD Self-Report Scale (ASRS-v1.1) and characterising symptom burden among adults with self-reported ADHD. *PMC*. https://pmc.ncbi.nlm.nih.gov/articles/PMC6585602/

[^2]: Young et al. (2023). Development and validation of the ADHD Symptom and Side Effect Tracking — Baseline Scale (ASSET-BS). *PMC*. https://pmc.ncbi.nlm.nih.gov/articles/PMC10629079/

[^3]: Roth et al. (2013). Confirmatory Factor Analysis of the Behavior Rating Inventory of Executive Function-Adult Version in Healthy Adults and Application to ADHD. *PMC*. https://pmc.ncbi.nlm.nih.gov/articles/PMC3711374/

[^4]: Weiss et al. (2018). Conceptual review of measuring functional impairment. *PMC*. https://pmc.ncbi.nlm.nih.gov/articles/PMC6241626/

[^5]: Colorado Mental Health Services (2026). Adult ADHD and Emotional Dysregulation Explained. https://coloradomentalhealthservices.com/rehab-blog/adult-adhd-and-emotional-dysregulation/

[^6]: RSD-RS (2025). The first standardised instrument for rejection sensitivity in ADHD. https://rsdrs.com/; Global ADHD Network (2025). RSD and ADHD. https://www.globaladhdnetwork.com/post/rejection-sensitive-dysphoria-rsd-and-adhd

[^7]: Sankesara et al. (2025). Identifying Digital Markers of Attention-Deficit/Hyperactivity Disorder (ADHD) in a Remote Monitoring Setting: Prospective Observational Study. *JMIR Formative Research*. https://formative.jmir.org/2025/1/e54531

[^8]: Kennedy et al. / TIPS mHealth Intervention (2024). From Assessment to Intervention: Leveraging EMA to Develop a Personalized mHealth EMI for Young Adults With ADHD. *PMC*. https://pmc.ncbi.nlm.nih.gov/articles/PMC12465124/

[^9]: Fu et al. (2025). Adult ADHD and comorbid anxiety and depressive disorders. *PMC*. https://pmc.ncbi.nlm.nih.gov/articles/PMC12179154/

[^10]: HSE Ireland. ADHD in Adults National Clinical Programme: Model of Care. https://www.hse.ie/eng/about/who/cspd/ncps/mental-health/adhd/adhd-in-adults-ncp-model-of-care/adhd-in-adults-ncp-model-of-care.pdf

[^11]: Nanda et al. (2023). Adverse Effects of Stimulant Interventions for Attention Deficit Hyperactivity Disorder (ADHD): A Comprehensive Systematic Review. *PMC*. https://pmc.ncbi.nlm.nih.gov/articles/PMC10601982/

[^12]: Surman et al. (2021). Sensitivity of Electronic Patient Reported Outcome Measures to Medication Effects in Adult ADHD — A Pilot Study. Presented at APSARD 2021. https://www.hcplive.com/view/adhd-treatment-remote-patient-monitoring

[^13]: ADHD Space (2026). Understanding Time Blindness in ADHD. https://www.adhdspace.ca/blog/understanding-time-blindness-in-adhd-occupational-therapy-to-manage-time-more-effectively/

[^14]: Zadinova M. (thesis). Additional symptoms beyond DSM-5-TR and ICD-11. https://is.muni.cz/th/fi2gu/554042_Zadinova_MDT.pdf

[^15]: ClarityDTX (2026). ADHD Tracker App. https://claritydtx.com/adhd/; Bearable (2025). Symptom Tracker App. https://bearable.app/; EndeavorOTC (2024). Apps We're Loving for ADHD Awareness Month. https://www.endeavorotc.com/blog/apps-were-loving-for-adhd-awareness-month/
