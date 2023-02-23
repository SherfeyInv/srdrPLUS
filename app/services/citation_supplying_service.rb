class CitationSupplyingService

  def find_by_project_id(project_id)
    citations = Project
                .find(project_id)
                .citations
                .includes(:journal)
                .all
    link_info = [
      {
        'relation' => 'tag',
        'url' => 'api/v3/projects/' + project_id.to_s + '/citations'
      },
      {
        'relation' => 'service-doc',
        'url' => 'doc/fhir/citation.txt'
      }
    ]
    create_bundle(objs=citations, type='collection', link_info=link_info)
  end

  def find_by_citation_id(citation_id)
    citation = Citation.find(citation_id)
    citation_in_fhir = create_fhir_obj(citation)

    return citation_in_fhir.validate unless citation_in_fhir.valid?

    citation_in_fhir
  end

  private

  def create_bundle(objs, type, link_info=nil)
    bundle = {
      'type' => type,
      'link' => link_info,
      'entry' => []
    }

    for obj in objs do
      fhir_obj = create_fhir_obj(obj)
      bundle['entry'].append({ 'resource' => fhir_obj }) if fhir_obj.valid?
    end

    FHIR::Bundle.new(bundle)
  end

  def create_fhir_obj(raw)
    citation = {
      'status' => 'active',
      'id' => '1' + '-' + raw.id.to_s,
      'identifier' => [{
        'type' => {
          'text' => 'SRDR+ Object Identifier'
        },
        'system' => 'https://srdrplus.ahrq.gov/',
        'value' => 'Citation/' + raw.id.to_s
      }],
      'citedArtifact' => {
        'identifier' => [],
        'title' => [],
        'abstract' => [],
        'publicationForm' => [],
        'contributorship' => {
          'entry' => []
        }
      }
    }

    authors = raw.authors.split(', ')
    for i in authors.size.times do
      author = {
        'resourceType' => 'Practitioner',
        'id' => 'author' + i.to_s,
        'name' => {
          'text' => authors[i]['name']
        }
      }
      entry = {
        'contributor' => {
          'reference' => '#author' + i.to_s
        }
      }
      if citation['contained']
        citation['contained'].append(author)
      else
        citation['contained'] = [author]
      end
      citation['citedArtifact']['contributorship']['entry'].append(entry)
    end

    journal = raw.journal
    if journal
      journal_info = {
        'publicationDateYear' => journal.publication_date,
        'volume' => journal.volume,
        'issue' => journal.issue,
        'publishedIn' => {
          'title' => journal.name
        }
      }
      citation['citedArtifact']['publicationForm'].append(journal_info)
    end

    title = raw.name
    unless title.empty?
      citation['citedArtifact']['title'].append({
                                                  'text' => title
                                                })
    end

    abstract = raw.abstract
    unless abstract.empty?
      citation['citedArtifact']['abstract'].append({
                                                     'text' => abstract
                                                   })
    end

    pmid = raw.pmid
    if pmid
      citation['citedArtifact']['identifier'].append({
                                                       'system' => 'https://pubmed.ncbi.nlm.nih.gov',
                                                       'value' => pmid
                                                     })
    end

    FHIR::Citation.new(citation)
  end
end
